import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/cafe_entities.dart';
import '../models/cafe_models.dart';

abstract class CafePosRemoteDataSource {
  Future<List<CafeModel>> getCafes();

  Future<CafeModel> upsertCafe(Cafe cafe);

  Future<CafeModel> uploadGuestLogo({
    required String cafeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });

  Future<CafeModel> clearGuestLogo(String cafeId);

  Future<List<CafeCategoryModel>> getCategories(String cafeId);

  Future<CafeCategoryModel> upsertCategory(CafeCategory category);

  Future<void> deleteCategory(String id);

  Future<List<CafeMenuItemModel>> getMenuItems(
    String cafeId, {
    bool availableOnly = false,
  });

  Future<CafeMenuItemModel> upsertMenuItem(CafeMenuItem item);

  Future<void> deleteMenuItem(String id);

  Future<List<CafeMenuAddonModel>> getMenuAddons(String menuItemId);

  Future<CafeMenuAddonModel> upsertMenuAddon(CafeMenuAddon addon);

  Future<void> deleteMenuAddon(String id);

  Future<List<CafeOrderModel>> getOrders(
    String cafeId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  });

  Future<CafeOrderModel> getOrder(String orderId);

  Future<CafeOrderModel> createOrder({
    required String cafeId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
    String? couponId,
    String couponCode = '',
    String tableNo = '',
  });

  Future<CafeOrderModel> updatePrepStatus({
    required String orderId,
    required CafePrepStatus status,
  });

  Future<CafeOrderModel> recordPayment({
    required String orderId,
    required CafePaymentMethod method,
    required double amount,
  });

  Future<CafeOrderModel> cancelOrder({
    required String orderId,
    required String reason,
  });

  /// Hard-delete all orders (and cascaded items/payments) for a cafe.
  Future<void> clearCafeOrders(String cafeId);

  Future<CafeDailyReport> getDailyReport({
    required String cafeId,
    required DateTime day,
  });

  Future<List<CafeCouponModel>> getCoupons(String cafeId);

  Future<CafeCouponModel?> lookupCoupon({
    required String cafeId,
    required String code,
  });

  Future<CafeCouponModel> upsertCoupon(CafeCoupon coupon);

  Future<void> deleteCoupon(String id);
}

class CafePosRemoteDataSourceImpl implements CafePosRemoteDataSource {
  CafePosRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _orderSelect = '*, cafe_order_items(*)';
  static const _brandLogosBucket = 'brand-logos';

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Never _schemaHint(PostgrestException e) {
    final msg = e.message.toLowerCase();
    // Only map real missing-relation errors — do not treat every cafe_*
    // RLS / check / column error as "tables missing".
    final missingRelation = e.code == '42P01' ||
        e.code == 'PGRST205' ||
        msg.contains('schema cache') ||
        msg.contains('could not find the table') ||
        (msg.contains('relation') && msg.contains('does not exist')) ||
        (msg.contains('could not find the') && msg.contains('in the schema cache'));
    if (missingRelation) {
      throw const ServerException(
        'Cafe POS tables are missing. Run cafe_pos.sql (and '
        'cafe_pos_coupons.sql / cafe_pos_tables.sql / '
        'cafe_pos_gst_settings.sql / cafe_pos_guest_brand.sql as needed), then '
        'security_hardening.sql or cafe_pos_rls_fix.sql.',
      );
    }
    throw ServerException(e.message);
  }

  bool _isGuestBrandColumnError(String message) {
    final msg = message.toLowerCase();
    return msg.contains('guest_logo') ||
        msg.contains('guest_show_logo') ||
        msg.contains('guest_tagline') ||
        msg.contains('guest_accent') ||
        msg.contains('guest_layout') ||
        msg.contains('guest_show_search');
  }

  @override
  Future<List<CafeModel>> getCafes() async {
    try {
      final rows = await _client
          .from('cafes')
          .select()
          .order('name');
      return (rows as List)
          .map((r) => CafeModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load cafes.');
    }
  }

  @override
  Future<CafeModel> upsertCafe(Cafe cafe) async {
    final id = cafe.id.trim().isEmpty ? _id('cafe') : cafe.id.trim();
    final payload = <String, dynamic>{
      'id': id,
      'name': cafe.name.trim(),
      'is_active': cafe.isActive,
      'show_gst_on_bill': cafe.showGstOnBill,
      'gst_label': cafe.gstLabel.trim().isEmpty ? 'GST' : cafe.gstLabel.trim(),
      'gst_split_halves': cafe.gstSplitHalves,
      'table_count': cafe.tableCount.clamp(1, 100),
      'guest_logo_path': cafe.guestLogoPath.trim(),
      'guest_show_logo': cafe.guestShowLogo,
      'guest_tagline': cafe.guestTagline.trim(),
      'guest_accent_hex': cafe.guestAccentHex.trim(),
      'guest_layout': cafe.guestLayout.dbValue,
      'guest_show_search': cafe.guestShowSearch,
    };
    try {
      final row =
          await _client.from('cafes').upsert(payload).select().single();
      return CafeModel.fromJson(row);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      // Guest brand must not be silently dropped — otherwise settings look
      // saved but the QR menu never changes.
      if (_isGuestBrandColumnError(msg)) {
        throw const ServerException(
          'Guest menu branding is not set up. Run cafe_pos_guest_brand.sql '
          'in Supabase, then save again.',
        );
      }
      // Older DBs — strip unknown GST / table columns progressively.
      if (msg.contains('show_gst') ||
          msg.contains('gst_label') ||
          msg.contains('gst_split') ||
          msg.contains('table_count')) {
        try {
          final stripped = <String, dynamic>{
            'id': id,
            'name': cafe.name.trim(),
            'is_active': cafe.isActive,
            'guest_logo_path': cafe.guestLogoPath.trim(),
            'guest_show_logo': cafe.guestShowLogo,
            'guest_tagline': cafe.guestTagline.trim(),
            'guest_accent_hex': cafe.guestAccentHex.trim(),
            'guest_layout': cafe.guestLayout.dbValue,
            'guest_show_search': cafe.guestShowSearch,
          };
          if (!msg.contains('show_gst') &&
              !msg.contains('gst_label') &&
              !msg.contains('gst_split')) {
            stripped['show_gst_on_bill'] = cafe.showGstOnBill;
            stripped['gst_label'] =
                cafe.gstLabel.trim().isEmpty ? 'GST' : cafe.gstLabel.trim();
            stripped['gst_split_halves'] = cafe.gstSplitHalves;
          }
          if (!msg.contains('table_count')) {
            stripped['table_count'] = cafe.tableCount.clamp(1, 100);
          }
          final row = await _client
              .from('cafes')
              .upsert(stripped)
              .select()
              .single();
          return CafeModel.fromJson(row);
        } on PostgrestException catch (e2) {
          if (_isGuestBrandColumnError(e2.message)) {
            throw const ServerException(
              'Guest menu branding is not set up. Run cafe_pos_guest_brand.sql '
              'in Supabase, then save again.',
            );
          }
          _schemaHint(e2);
        }
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save cafe.');
    }
  }

  @override
  Future<CafeModel> uploadGuestLogo({
    required String cafeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) {
      throw const ServerException('Choose an image to upload.');
    }
    final id = cafeId.trim();
    if (id.isEmpty) {
      throw const ServerException('Cafe id is required.');
    }

    var safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
    if (safeName.isEmpty) safeName = 'logo.jpg';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'jpg';
    final path =
        'cafes/$id/guest_logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType =
        mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim();

    try {
      final existing = await _client
          .from('cafes')
          .select('guest_logo_path')
          .eq('id', id)
          .maybeSingle();
      final previous = (existing?['guest_logo_path'] ?? '').toString().trim();

      await _client.storage.from(_brandLogosBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final row = await _client
          .from('cafes')
          .update({'guest_logo_path': path})
          .eq('id', id)
          .select()
          .single();

      if (previous.isNotEmpty && previous != path) {
        try {
          await _client.storage.from(_brandLogosBucket).remove([previous]);
        } catch (_) {}
      }

      return CafeModel.fromJson(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      if (_isGuestBrandColumnError(e.message)) {
        throw const ServerException(
          'Guest menu branding is not set up. Run cafe_pos_guest_brand.sql.',
        );
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to upload guest logo.');
    }
  }

  @override
  Future<CafeModel> clearGuestLogo(String cafeId) async {
    final id = cafeId.trim();
    if (id.isEmpty) {
      throw const ServerException('Cafe id is required.');
    }
    try {
      final existing = await _client
          .from('cafes')
          .select('guest_logo_path')
          .eq('id', id)
          .maybeSingle();
      final previous = (existing?['guest_logo_path'] ?? '').toString().trim();

      final row = await _client
          .from('cafes')
          .update({'guest_logo_path': ''})
          .eq('id', id)
          .select()
          .single();

      if (previous.isNotEmpty) {
        try {
          await _client.storage.from(_brandLogosBucket).remove([previous]);
        } catch (_) {}
      }

      return CafeModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (_isGuestBrandColumnError(e.message)) {
        throw const ServerException(
          'Guest menu branding is not set up. Run cafe_pos_guest_brand.sql.',
        );
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to remove guest logo.');
    }
  }

  @override
  Future<List<CafeCategoryModel>> getCategories(String cafeId) async {
    try {
      final rows = await _client
          .from('cafe_categories')
          .select()
          .eq('cafe_id', cafeId)
          .order('sort_order')
          .order('name');
      return (rows as List)
          .map((r) => CafeCategoryModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load categories.');
    }
  }

  @override
  Future<CafeCategoryModel> upsertCategory(CafeCategory category) async {
    final id = category.id.trim().isEmpty ? _id('ccat') : category.id.trim();
    try {
      final row = await _client
          .from('cafe_categories')
          .upsert({
            'id': id,
            'cafe_id': category.cafeId,
            'name': category.name.trim(),
            'sort_order': category.sortOrder,
            'is_active': category.isActive,
          })
          .select()
          .single();
      return CafeCategoryModel.fromJson(row);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save category.');
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _client.from('cafe_categories').delete().eq('id', id);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete category.');
    }
  }

  @override
  Future<List<CafeMenuItemModel>> getMenuItems(
    String cafeId, {
    bool availableOnly = false,
  }) async {
    try {
      var query = _client
          .from('cafe_menu_items')
          .select('*, cafe_categories(name)')
          .eq('cafe_id', cafeId)
          .eq('is_active', true);
      if (availableOnly) {
        query = query.eq('is_available', true);
      }
      final rows = await query.order('sort_order').order('name');
      final addonsByItem = await _addonsByMenuItem(cafeId);
      return (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final id = (map['id'] ?? '').toString();
        return CafeMenuItemModel.fromJson(
          map,
          addons: addonsByItem[id] ?? const [],
        );
      }).toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load menu.');
    }
  }

  Future<Map<String, List<CafeMenuAddon>>> _addonsByMenuItem(
    String cafeId,
  ) async {
    try {
      final rows = await _client
          .from('cafe_menu_addons')
          .select()
          .eq('cafe_id', cafeId)
          .eq('is_active', true)
          .order('sort_order')
          .order('name');
      final map = <String, List<CafeMenuAddon>>{};
      for (final row in rows as List) {
        if (row is! Map) continue;
        final addon =
            CafeMenuAddonModel.fromJson(Map<String, dynamic>.from(row));
        map.putIfAbsent(addon.menuItemId, () => []).add(addon);
      }
      return map;
    } on PostgrestException {
      // Add-ons table optional until cafe_pos_menu_addons.sql is applied.
      return {};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<CafeMenuAddonModel>> getMenuAddons(String menuItemId) async {
    try {
      final rows = await _client
          .from('cafe_menu_addons')
          .select()
          .eq('menu_item_id', menuItemId)
          .eq('is_active', true)
          .order('sort_order')
          .order('name');
      return (rows as List)
          .map(
            (r) => CafeMenuAddonModel.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cafe_menu_addons') || msg.contains('schema cache')) {
        return const [];
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load add-ons.');
    }
  }

  @override
  Future<CafeMenuAddonModel> upsertMenuAddon(CafeMenuAddon addon) async {
    final id = addon.id.trim().isEmpty ? _id('cadd') : addon.id.trim();
    try {
      final row = await _client
          .from('cafe_menu_addons')
          .upsert({
            'id': id,
            'cafe_id': addon.cafeId,
            'menu_item_id': addon.menuItemId,
            'name': addon.name.trim(),
            'price': addon.price,
            'is_active': addon.isActive,
            'sort_order': addon.sortOrder,
          })
          .select()
          .single();
      return CafeMenuAddonModel.fromJson(row);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cafe_menu_addons') || msg.contains('schema cache')) {
        throw const ServerException(
          'Add-ons are not set up. Run cafe_pos_menu_addons.sql in Supabase.',
        );
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save add-on.');
    }
  }

  @override
  Future<void> deleteMenuAddon(String id) async {
    try {
      await _client
          .from('cafe_menu_addons')
          .update({'is_active': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cafe_menu_addons') || msg.contains('schema cache')) {
        throw const ServerException(
          'Add-ons are not set up. Run cafe_pos_menu_addons.sql in Supabase.',
        );
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to remove add-on.');
    }
  }

  @override
  Future<CafeMenuItemModel> upsertMenuItem(CafeMenuItem item) async {
    final id = item.id.trim().isEmpty ? _id('citem') : item.id.trim();
    final base = <String, dynamic>{
      'id': id,
      'cafe_id': item.cafeId,
      'category_id': item.categoryId,
      'name': item.name.trim(),
      'price': item.price,
      'tax_rate': item.taxRate,
      'is_available': item.isAvailable,
      'is_active': item.isActive,
      'sort_order': item.sortOrder,
    };
    try {
      try {
        final row = await _client
            .from('cafe_menu_items')
            .upsert({
              ...base,
              'description': item.description.trim(),
            })
            .select('*, cafe_categories(name)')
            .single();
        return CafeMenuItemModel.fromJson(row);
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        if (!msg.contains('description')) rethrow;
        final row = await _client
            .from('cafe_menu_items')
            .upsert(base)
            .select('*, cafe_categories(name)')
            .single();
        return CafeMenuItemModel.fromJson(row);
      }
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save menu item.');
    }
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    try {
      await _client
          .from('cafe_menu_items')
          .update({'is_active': false})
          .eq('id', id);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to deactivate menu item.');
    }
  }

  @override
  Future<List<CafeOrderModel>> getOrders(
    String cafeId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  }) async {
    try {
      var query = _client
          .from('cafe_orders')
          .select(_orderSelect)
          .eq('cafe_id', cafeId);

      if (day != null) {
        final start = DateTime(day.year, day.month, day.day).toUtc();
        final end = start.add(const Duration(days: 1));
        query = query
            .gte('created_at', start.toIso8601String())
            .lt('created_at', end.toIso8601String());
      }
      if (prepStatuses != null && prepStatuses.isNotEmpty) {
        query = query.inFilter(
          'prep_status',
          prepStatuses.map((s) => s.dbValue).toList(),
        );
      }

      final rows = await query.order('created_at', ascending: false);
      return (rows as List)
          .map((r) => CafeOrderModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load orders.');
    }
  }

  @override
  Future<CafeOrderModel> getOrder(String orderId) async {
    try {
      final row = await _client
          .from('cafe_orders')
          .select(_orderSelect)
          .eq('id', orderId)
          .single();
      return CafeOrderModel.fromJson(row);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load order.');
    }
  }

  Future<String> _nextOrderNo(String cafeId) async {
    final now = DateTime.now();
    final prefix =
        'C${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('cafe_orders')
        .select('order_no')
        .eq('cafe_id', cafeId)
        .like('order_no', '$prefix-%');
    var maxSeq = 0;
    for (final row in rows as List) {
      final no = (row as Map)['order_no']?.toString() ?? '';
      final parts = no.split('-');
      if (parts.length != 2) continue;
      final seq = int.tryParse(parts[1]) ?? 0;
      if (seq > maxSeq) maxSeq = seq;
    }
    return '$prefix-${(maxSeq + 1).toString().padLeft(3, '0')}';
  }

  @override
  Future<CafeOrderModel> createOrder({
    required String cafeId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
    String? couponId,
    String couponCode = '',
    String tableNo = '',
  }) async {
    if (lines.isEmpty) {
      throw const ServerException('Add at least one item.');
    }
    final normalizedTable =
        orderType == CafeOrderType.dineIn ? tableNo.trim() : '';
    try {
      var subtotal = 0.0;
      var tax = 0.0;
      final itemRows = <Map<String, dynamic>>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineTotal = line.lineTotal;
        final lineTax = lineTotal * (line.menuItem.taxRate / 100);
        subtotal += lineTotal;
        tax += lineTax;
        final noteParts = <String>[
          if (line.notes.trim().isNotEmpty) line.notes.trim(),
          if (line.addons.isNotEmpty)
            'Add-ons: ${line.addons.map((a) => a.name).join(', ')}',
        ];
        itemRows.add(
          CafeOrderItemModel(
            id: _id('coli'),
            menuItemId: line.menuItem.id,
            itemName: line.displayName,
            unitPrice: line.unitPrice,
            taxRate: line.menuItem.taxRate,
            quantity: line.quantity,
            lineTotal: lineTotal,
            notes: noteParts.join(' · '),
            sortOrder: i,
          ).toJson(orderId: 'pending'),
        );
      }
      final discount = discountAmount < 0 ? 0.0 : discountAmount;
      final total = (subtotal + tax - discount).clamp(0.0, double.infinity);
      final orderId = _id('cord');
      final orderNo = await _nextOrderNo(cafeId);
      final uid = _client.auth.currentUser?.id;

      for (final row in itemRows) {
        row['order_id'] = orderId;
      }

      final baseOrder = <String, dynamic>{
        'id': orderId,
        'cafe_id': cafeId,
        'order_no': orderNo,
        'order_type': orderType.dbValue,
        'prep_status': CafePrepStatus.neu.dbValue,
        'payment_status': CafePaymentStatus.pending.dbValue,
        'subtotal': subtotal,
        'tax_amount': tax,
        'discount_amount': discount,
        'total_amount': total,
        'created_by': uid,
      };
      final withExtras = <String, dynamic>{
        ...baseOrder,
        'coupon_id': couponId,
        'coupon_code': couponCode.trim().toUpperCase(),
        'table_no': normalizedTable,
      };
      try {
        await _client.from('cafe_orders').insert(withExtras);
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('table_no')) {
          try {
            await _client.from('cafe_orders').insert({
              ...baseOrder,
              'coupon_id': couponId,
              'coupon_code': couponCode.trim().toUpperCase(),
            });
          } on PostgrestException catch (e2) {
            final msg2 = e2.message.toLowerCase();
            if (msg2.contains('coupon_')) {
              await _client.from('cafe_orders').insert(baseOrder);
            } else {
              rethrow;
            }
          }
        } else if (msg.contains('coupon_')) {
          try {
            await _client.from('cafe_orders').insert({
              ...baseOrder,
              'table_no': normalizedTable,
            });
          } on PostgrestException catch (e2) {
            if (e2.message.toLowerCase().contains('table_no')) {
              await _client.from('cafe_orders').insert(baseOrder);
            } else {
              rethrow;
            }
          }
        } else {
          rethrow;
        }
      }
      await _client.from('cafe_order_items').insert(itemRows);
      return await getOrder(orderId);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to create order.');
    }
  }

  @override
  Future<CafeOrderModel> updatePrepStatus({
    required String orderId,
    required CafePrepStatus status,
  }) async {
    try {
      await _client.from('cafe_orders').update({
        'prep_status': status.dbValue,
      }).eq('id', orderId);
      return await getOrder(orderId);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update order status.');
    }
  }

  @override
  Future<CafeOrderModel> recordPayment({
    required String orderId,
    required CafePaymentMethod method,
    required double amount,
  }) async {
    try {
      final existing = await getOrder(orderId);
      if (existing.prepStatus == CafePrepStatus.cancelled) {
        throw const ServerException('Cannot pay a cancelled order.');
      }
      final uid = _client.auth.currentUser?.id;
      await _client.from('cafe_payments').insert({
        'id': _id('cpay'),
        'order_id': orderId,
        'cafe_id': existing.cafeId,
        'method': method.dbValue,
        'amount': amount,
        'recorded_by': uid,
      });
      await _client.from('cafe_orders').update({
        'payment_status': CafePaymentStatus.paid.dbValue,
      }).eq('id', orderId);
      final couponId = existing.couponId;
      if (couponId != null && couponId.isNotEmpty) {
        try {
          final row = await _client
              .from('cafe_coupons')
              .select('usage_count')
              .eq('id', couponId)
              .maybeSingle();
          final current = (row?['usage_count'] as num?)?.toInt() ?? 0;
          await _client.from('cafe_coupons').update({
            'usage_count': current + 1,
          }).eq('id', couponId);
        } catch (_) {
          // Non-fatal: order is already paid.
        }
      }
      return await getOrder(orderId);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to record payment.');
    }
  }

  @override
  Future<CafeOrderModel> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Cancellation reason is required.');
    }
    try {
      final uid = _client.auth.currentUser?.id;
      await _client.from('cafe_orders').update({
        'prep_status': CafePrepStatus.cancelled.dbValue,
        'cancel_reason': trimmed,
        'cancelled_by': uid,
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
      return await getOrder(orderId);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to cancel order.');
    }
  }

  @override
  Future<void> clearCafeOrders(String cafeId) async {
    final id = cafeId.trim();
    if (id.isEmpty) {
      throw const ServerException('Cafe id is required.');
    }
    try {
      // Payments / items cascade from cafe_orders when FKs are set.
      await _client.from('cafe_payments').delete().eq('cafe_id', id);
      await _client.from('cafe_orders').delete().eq('cafe_id', id);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to clear orders.');
    }
  }

  @override
  Future<CafeDailyReport> getDailyReport({
    required String cafeId,
    required DateTime day,
  }) async {
    try {
      final orders = await getOrders(cafeId, day: day);
      final paid = orders
          .where(
            (o) =>
                o.paymentStatus == CafePaymentStatus.paid &&
                o.prepStatus != CafePrepStatus.cancelled,
          )
          .toList();

      final start = DateTime(day.year, day.month, day.day).toUtc();
      final end = start.add(const Duration(days: 1));
      final payRows = await _client
          .from('cafe_payments')
          .select()
          .eq('cafe_id', cafeId)
          .gte('recorded_at', start.toIso8601String())
          .lt('recorded_at', end.toIso8601String());

      final byMethod = <CafePaymentMethod, double>{
        for (final m in CafePaymentMethodX.checkoutOptions) m: 0,
      };
      for (final row in payRows as List) {
        final map = row as Map<String, dynamic>;
        final method =
            CafePaymentMethodX.fromDb(map['method']?.toString());
        final amount = (map['amount'] as num?)?.toDouble() ?? 0;
        byMethod[method] = (byMethod[method] ?? 0) + amount;
      }

      final itemMap = <String, CafeItemSale>{};
      for (final order in paid) {
        for (final item in order.items) {
          final prev = itemMap[item.itemName];
          itemMap[item.itemName] = CafeItemSale(
            itemName: item.itemName,
            quantity: (prev?.quantity ?? 0) + item.quantity,
            value: (prev?.value ?? 0) + item.lineTotal,
          );
        }
      }
      final itemSales = itemMap.values.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final totalSales =
          paid.fold<double>(0, (s, o) => s + o.totalAmount);

      return CafeDailyReport(
        date: DateTime(day.year, day.month, day.day),
        orderCount: paid.length,
        totalSales: totalSales,
        byPaymentMethod: byMethod,
        itemSales: itemSales,
      );
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load report.');
    }
  }

  @override
  Future<List<CafeCouponModel>> getCoupons(String cafeId) async {
    try {
      final rows = await _client
          .from('cafe_coupons')
          .select()
          .eq('cafe_id', cafeId)
          .order('code');
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(CafeCouponModel.fromJson)
          .toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load coupons.');
    }
  }

  @override
  Future<CafeCouponModel?> lookupCoupon({
    required String cafeId,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final row = await _client
          .from('cafe_coupons')
          .select()
          .eq('cafe_id', cafeId)
          .eq('code', normalized)
          .maybeSingle();
      if (row == null) return null;
      return CafeCouponModel.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to look up coupon.');
    }
  }

  @override
  Future<CafeCouponModel> upsertCoupon(CafeCoupon coupon) async {
    final code = coupon.code.trim().toUpperCase();
    if (code.isEmpty) {
      throw const ServerException('Coupon code is required.');
    }
    if (coupon.discountValue <= 0) {
      throw const ServerException('Discount value must be greater than zero.');
    }
    if (coupon.discountType == CafeDiscountType.percent &&
        coupon.discountValue > 100) {
      throw const ServerException('Percent discount cannot exceed 100.');
    }
    try {
      final id = coupon.id.trim().isEmpty ? _id('ccup') : coupon.id;
      final model = CafeCouponModel(
        id: id,
        cafeId: coupon.cafeId,
        code: code,
        name: coupon.name,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
        minOrderAmount: coupon.minOrderAmount,
        maxDiscountAmount: coupon.maxDiscountAmount,
        isActive: coupon.isActive,
        startsAt: coupon.startsAt,
        endsAt: coupon.endsAt,
        maxUses: coupon.maxUses,
        usageCount: coupon.usageCount,
      );
      await _client.from('cafe_coupons').upsert(model.toJson());
      final row = await _client
          .from('cafe_coupons')
          .select()
          .eq('id', id)
          .single();
      return CafeCouponModel.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('A coupon with this code already exists.');
      }
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save coupon.');
    }
  }

  @override
  Future<void> deleteCoupon(String id) async {
    try {
      await _client.from('cafe_coupons').delete().eq('id', id);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete coupon.');
    }
  }
}
