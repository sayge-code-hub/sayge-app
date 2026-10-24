import '../../domain/entities/cafe_entities.dart';

class CafeModel extends Cafe {
  const CafeModel({
    required super.id,
    required super.name,
    super.isActive,
  });

  factory CafeModel.fromJson(Map<String, dynamic> json) {
    return CafeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_active': isActive,
      };
}

class CafeCategoryModel extends CafeCategory {
  const CafeCategoryModel({
    required super.id,
    required super.cafeId,
    required super.name,
    super.sortOrder,
    super.isActive,
  });

  factory CafeCategoryModel.fromJson(Map<String, dynamic> json) {
    return CafeCategoryModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'name': name,
        'sort_order': sortOrder,
        'is_active': isActive,
      };
}

class CafeMenuItemModel extends CafeMenuItem {
  const CafeMenuItemModel({
    required super.id,
    required super.cafeId,
    required super.categoryId,
    required super.name,
    required super.price,
    super.taxRate,
    super.isAvailable,
    super.isActive,
    super.sortOrder,
    super.categoryName,
  });

  factory CafeMenuItemModel.fromJson(Map<String, dynamic> json) {
    final cat = json['cafe_categories'];
    final catMap = cat is Map<String, dynamic> ? cat : null;
    return CafeMenuItemModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] != false,
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      categoryName: (catMap?['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'category_id': categoryId,
        'name': name,
        'price': price,
        'tax_rate': taxRate,
        'is_available': isAvailable,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

class CafeOrderItemModel extends CafeOrderItem {
  const CafeOrderItemModel({
    required super.id,
    required super.menuItemId,
    required super.itemName,
    required super.unitPrice,
    required super.quantity,
    required super.lineTotal,
    super.taxRate,
    super.notes,
    super.sortOrder,
  });

  factory CafeOrderItemModel.fromJson(Map<String, dynamic> json) {
    return CafeOrderItemModel(
      id: (json['id'] ?? '').toString(),
      menuItemId: json['menu_item_id']?.toString(),
      itemName: (json['item_name'] ?? '').toString(),
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      notes: (json['notes'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson({required String orderId}) => {
        'id': id,
        'order_id': orderId,
        'menu_item_id': menuItemId,
        'item_name': itemName,
        'unit_price': unitPrice,
        'tax_rate': taxRate,
        'quantity': quantity,
        'line_total': lineTotal,
        'notes': notes,
        'sort_order': sortOrder,
      };
}

class CafeOrderModel extends CafeOrder {
  const CafeOrderModel({
    required super.id,
    required super.cafeId,
    required super.orderNo,
    required super.orderType,
    required super.prepStatus,
    required super.paymentStatus,
    required super.subtotal,
    required super.taxAmount,
    required super.discountAmount,
    required super.totalAmount,
    required super.createdAt,
    super.items,
    super.cancelReason,
    super.cancelledAt,
  });

  factory CafeOrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['cafe_order_items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(CafeOrderItemModel.fromJson)
            .toList()
        : <CafeOrderItem>[];
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return CafeOrderModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      orderNo: (json['order_no'] ?? '').toString(),
      orderType: CafeOrderTypeX.fromDb(json['order_type']?.toString()),
      prepStatus: CafePrepStatusX.fromDb(json['prep_status']?.toString()),
      paymentStatus:
          CafePaymentStatusX.fromDb(json['payment_status']?.toString()),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      items: items,
      cancelReason: (json['cancel_reason'] ?? '').toString(),
      cancelledAt:
          DateTime.tryParse((json['cancelled_at'] ?? '').toString()),
    );
  }
}
