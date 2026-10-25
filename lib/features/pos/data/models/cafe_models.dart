import '../../domain/entities/cafe_entities.dart';

class CafeModel extends Cafe {
  const CafeModel({
    required super.id,
    required super.name,
    super.isActive,
    super.showGstOnBill,
    super.gstLabel,
    super.gstSplitHalves,
    super.tableCount,
    super.guestLogoPath,
    super.guestShowLogo,
    super.guestTagline,
    super.guestAccentHex,
    super.guestLayout,
    super.guestShowSearch,
    super.createdAt,
  });

  factory CafeModel.fromJson(Map<String, dynamic> json) {
    final label = (json['gst_label'] ?? 'GST').toString().trim();
    final tables = (json['table_count'] as num?)?.toInt() ?? 16;
    final accent = (json['guest_accent_hex'] ?? '').toString().trim();
    final createdRaw = json['created_at']?.toString();
    return CafeModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isActive: json['is_active'] != false,
      showGstOnBill: json['show_gst_on_bill'] != false,
      gstLabel: label.isEmpty ? 'GST' : label,
      gstSplitHalves: json['gst_split_halves'] == true,
      tableCount: tables.clamp(1, 100),
      guestLogoPath: (json['guest_logo_path'] ?? '').toString(),
      guestShowLogo: json['guest_show_logo'] != false,
      guestTagline: (json['guest_tagline'] ?? '').toString(),
      guestAccentHex: accent,
      guestLayout: GuestMenuLayoutX.fromDb(json['guest_layout']?.toString()),
      guestShowSearch: json['guest_show_search'] == true,
      createdAt: createdRaw == null || createdRaw.isEmpty
          ? null
          : DateTime.tryParse(createdRaw)?.toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_active': isActive,
        'show_gst_on_bill': showGstOnBill,
        'gst_label': gstLabel.trim().isEmpty ? 'GST' : gstLabel.trim(),
        'gst_split_halves': gstSplitHalves,
        'table_count': tableCount.clamp(1, 100),
        'guest_logo_path': guestLogoPath.trim(),
        'guest_show_logo': guestShowLogo,
        'guest_tagline': guestTagline.trim(),
        'guest_accent_hex': guestAccentHex.trim(),
        'guest_layout': guestLayout.dbValue,
        'guest_show_search': guestShowSearch,
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

class CafeMenuAddonModel extends CafeMenuAddon {
  const CafeMenuAddonModel({
    required super.id,
    required super.cafeId,
    required super.menuItemId,
    required super.name,
    required super.price,
    super.isActive,
    super.sortOrder,
  });

  factory CafeMenuAddonModel.fromJson(Map<String, dynamic> json) {
    return CafeMenuAddonModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      menuItemId: (json['menu_item_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'menu_item_id': menuItemId,
        'name': name.trim(),
        'price': price,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

class CafeMenuItemModel extends CafeMenuItem {
  const CafeMenuItemModel({
    required super.id,
    required super.cafeId,
    required super.categoryId,
    required super.name,
    required super.price,
    super.description,
    super.taxRate,
    super.isAvailable,
    super.isActive,
    super.sortOrder,
    super.categoryName,
    super.addons,
  });

  factory CafeMenuItemModel.fromJson(
    Map<String, dynamic> json, {
    List<CafeMenuAddon> addons = const [],
  }) {
    final cat = json['cafe_categories'];
    final catMap = cat is Map ? Map<String, dynamic>.from(cat) : null;
    return CafeMenuItemModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      categoryId: (json['category_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      description: (json['description'] ?? '').toString(),
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] != false,
      isActive: json['is_active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      categoryName: (catMap?['name'] ?? '').toString(),
      addons: addons,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'category_id': categoryId,
        'name': name,
        'price': price,
        'description': description,
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
    super.couponId,
    super.couponCode,
    super.tableNo,
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

    final couponIdRaw = (json['coupon_id'] ?? '').toString().trim();
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
      couponId: couponIdRaw.isEmpty ? null : couponIdRaw,
      couponCode: (json['coupon_code'] ?? '').toString(),
      tableNo: (json['table_no'] ?? '').toString().trim(),
    );
  }
}

class CafeCouponModel extends CafeCoupon {
  const CafeCouponModel({
    required super.id,
    required super.cafeId,
    required super.code,
    required super.discountType,
    required super.discountValue,
    super.name,
    super.minOrderAmount,
    super.maxDiscountAmount,
    super.isActive,
    super.startsAt,
    super.endsAt,
    super.maxUses,
    super.usageCount,
  });

  factory CafeCouponModel.fromJson(Map<String, dynamic> json) {
    return CafeCouponModel(
      id: (json['id'] ?? '').toString(),
      cafeId: (json['cafe_id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      discountType: CafeDiscountTypeX.fromDb(json['discount_type']?.toString()),
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      maxDiscountAmount: (json['max_discount_amount'] as num?)?.toDouble(),
      isActive: json['is_active'] != false,
      startsAt: DateTime.tryParse((json['starts_at'] ?? '').toString()),
      endsAt: DateTime.tryParse((json['ends_at'] ?? '').toString()),
      maxUses: (json['max_uses'] as num?)?.toInt(),
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cafe_id': cafeId,
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'discount_type': discountType.dbValue,
        'discount_value': discountValue,
        'min_order_amount': minOrderAmount,
        'max_discount_amount': maxDiscountAmount,
        'is_active': isActive,
        'starts_at': startsAt?.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
        'max_uses': maxUses,
        'usage_count': usageCount,
      };
}
