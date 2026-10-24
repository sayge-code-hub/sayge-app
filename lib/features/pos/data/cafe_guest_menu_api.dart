import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exceptions.dart';
import '../domain/entities/cafe_entities.dart';

class GuestCafeMenu {
  const GuestCafeMenu({
    required this.cafeId,
    required this.cafeName,
    required this.categories,
    required this.items,
  });

  final String cafeId;
  final String cafeName;
  final List<CafeCategory> categories;
  final List<CafeMenuItem> items;
}

class GuestOrderResult {
  const GuestOrderResult({
    required this.id,
    required this.orderNo,
    required this.cafeName,
    required this.totalAmount,
    required this.tableNo,
    required this.orderType,
    required this.itemCount,
  });

  final String id;
  final String orderNo;
  final String cafeName;
  final double totalAmount;
  final String tableNo;
  final CafeOrderType orderType;
  final int itemCount;
}

/// Public QR menu RPCs (anon-safe).
class CafeGuestMenuApi {
  CafeGuestMenuApi({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<GuestCafeMenu> fetchMenu(String cafeId) async {
    try {
      final raw = await _client.rpc(
        'get_guest_cafe_menu',
        params: {'p_cafe_id': cafeId},
      );
      if (raw is! Map) {
        throw const ServerException('Could not load menu.');
      }
      final map = Map<String, dynamic>.from(raw);
      final cafe = Map<String, dynamic>.from(map['cafe'] as Map? ?? {});
      final catsRaw = map['categories'];
      final itemsRaw = map['items'];
      final categories = <CafeCategory>[];
      if (catsRaw is List) {
        for (final row in catsRaw) {
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          categories.add(
            CafeCategory(
              id: (m['id'] ?? '').toString(),
              cafeId: cafeId,
              name: (m['name'] ?? '').toString(),
              sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      }
      final items = <CafeMenuItem>[];
      if (itemsRaw is List) {
        for (final row in itemsRaw) {
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          items.add(
            CafeMenuItem(
              id: (m['id'] ?? '').toString(),
              cafeId: cafeId,
              categoryId: (m['category_id'] ?? '').toString(),
              name: (m['name'] ?? '').toString(),
              price: (m['price'] as num?)?.toDouble() ?? 0,
              taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0,
              sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
              categoryName: (m['category_name'] ?? '').toString(),
              isAvailable: true,
              isActive: true,
            ),
          );
        }
      }
      return GuestCafeMenu(
        cafeId: (cafe['id'] ?? cafeId).toString(),
        cafeName: (cafe['name'] ?? 'Cafe').toString(),
        categories: categories,
        items: items,
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('function') ||
          msg.contains('schema cache') ||
          e.code == 'PGRST202') {
        throw const ServerException(
          'Guest menu is not set up. Run cafe_pos_guest_menu.sql in Supabase.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load menu.');
    }
  }

  Future<GuestOrderResult> placeOrder({
    required String cafeId,
    required List<CafeCartLine> lines,
    String tableNo = '',
    CafeOrderType orderType = CafeOrderType.dineIn,
  }) async {
    if (lines.isEmpty) {
      throw const ServerException('Add at least one item.');
    }
    try {
      final payload = [
        for (final line in lines)
          {
            'menu_item_id': line.menuItem.id,
            'quantity': line.quantity,
            'notes': line.notes.trim(),
          },
      ];
      final raw = await _client.rpc(
        'create_guest_cafe_order',
        params: {
          'p_cafe_id': cafeId,
          'p_items': payload,
          'p_table_no': tableNo.trim(),
          'p_order_type': orderType.dbValue,
        },
      );
      if (raw is! Map) {
        throw const ServerException('Could not place order.');
      }
      final m = Map<String, dynamic>.from(raw);
      return GuestOrderResult(
        id: (m['id'] ?? '').toString(),
        orderNo: (m['order_no'] ?? '').toString(),
        cafeName: (m['cafe_name'] ?? '').toString(),
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        tableNo: (m['table_no'] ?? '').toString(),
        orderType: CafeOrderTypeX.fromDb(m['order_type']?.toString()),
        itemCount: (m['item_count'] as num?)?.toInt() ?? lines.length,
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('function') ||
          msg.contains('schema cache') ||
          e.code == 'PGRST202') {
        throw const ServerException(
          'Guest ordering is not set up. Run cafe_pos_guest_menu.sql '
          '(and cafe_pos_tables.sql) in Supabase.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to place order.');
    }
  }
}
