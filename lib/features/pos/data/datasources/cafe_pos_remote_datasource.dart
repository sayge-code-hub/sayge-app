import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/cafe_entities.dart';
import '../models/cafe_models.dart';

abstract class CafePosRemoteDataSource {
  Future<List<CafeModel>> getCafes();

  Future<CafeModel> upsertCafe(Cafe cafe);

  Future<List<CafeCategoryModel>> getCategories(String cafeId);

  Future<CafeCategoryModel> upsertCategory(CafeCategory category);

  Future<void> deleteCategory(String id);

  Future<List<CafeMenuItemModel>> getMenuItems(
    String cafeId, {
    bool availableOnly = false,
  });

  Future<CafeMenuItemModel> upsertMenuItem(CafeMenuItem item);

  Future<void> deleteMenuItem(String id);

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

  Future<CafeDailyReport> getDailyReport({
    required String cafeId,
    required DateTime day,
  });
}

class CafePosRemoteDataSourceImpl implements CafePosRemoteDataSource {
  CafePosRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _orderSelect = '*, cafe_order_items(*)';

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Never _schemaHint(PostgrestException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('cafe_') ||
        msg.contains('schema cache') ||
        e.code == '42P01' ||
        e.code == 'PGRST205') {
      throw const ServerException(
        'Cafe POS tables are missing. If you previously installed the '
        'client-scoped pack, run cafe_pos_reset_to_cafes.sql, then '
        'cafe_pos.sql, then security_hardening.sql.',
      );
    }
    throw ServerException(e.message);
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
    try {
      final row = await _client
          .from('cafes')
          .upsert({
            'id': id,
            'name': cafe.name.trim(),
            'is_active': cafe.isActive,
          })
          .select()
          .single();
      return CafeModel.fromJson(row);
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save cafe.');
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
      return (rows as List)
          .map((r) => CafeMenuItemModel.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      _schemaHint(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load menu.');
    }
  }

  @override
  Future<CafeMenuItemModel> upsertMenuItem(CafeMenuItem item) async {
    final id = item.id.trim().isEmpty ? _id('citem') : item.id.trim();
    try {
      final row = await _client
          .from('cafe_menu_items')
          .upsert({
            'id': id,
            'cafe_id': item.cafeId,
            'category_id': item.categoryId,
            'name': item.name.trim(),
            'price': item.price,
            'tax_rate': item.taxRate,
            'is_available': item.isAvailable,
            'is_active': item.isActive,
            'sort_order': item.sortOrder,
          })
          .select('*, cafe_categories(name)')
          .single();
      return CafeMenuItemModel.fromJson(row);
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
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from('cafe_orders')
        .select('order_no')
        .eq('cafe_id', cafeId)
        .gte('created_at', start.toIso8601String())
        .lt('created_at', end.toIso8601String());
    final count = (rows as List).length + 1;
    return '$prefix-${count.toString().padLeft(3, '0')}';
  }

  @override
  Future<CafeOrderModel> createOrder({
    required String cafeId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
  }) async {
    if (lines.isEmpty) {
      throw const ServerException('Add at least one item.');
    }
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
        itemRows.add(
          CafeOrderItemModel(
            id: _id('coli'),
            menuItemId: line.menuItem.id,
            itemName: line.menuItem.name,
            unitPrice: line.menuItem.price,
            taxRate: line.menuItem.taxRate,
            quantity: line.quantity,
            lineTotal: lineTotal,
            notes: line.notes.trim(),
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

      await _client.from('cafe_orders').insert({
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
      });
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
        for (final m in CafePaymentMethod.values) m: 0,
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
}
