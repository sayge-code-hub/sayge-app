import '../../domain/entities/pos_entities.dart';

class PosBrandModel extends PosBrand {
  const PosBrandModel({
    required super.id,
    required super.name,
    super.description,
    super.logoPath,
    super.isActive,
    super.createdAt,
  });

  factory PosBrandModel.fromJson(Map<String, dynamic> json) {
    return PosBrandModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      logoPath: (json['logo_path'] ?? '').toString(),
      isActive: json['is_active'] == true ||
          json['is_active']?.toString().toLowerCase() == 'true',
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'logo_path': logoPath,
        'is_active': isActive,
      };
}

class PosProductImageModel extends PosProductImage {
  const PosProductImageModel({
    required super.id,
    required super.productId,
    required super.storagePath,
    super.fileName,
    super.sortOrder,
    super.isPrimary,
  });

  factory PosProductImageModel.fromJson(Map<String, dynamic> json) {
    return PosProductImageModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      storagePath: (json['storage_path'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
      isPrimary: json['is_primary'] == true ||
          json['is_primary']?.toString().toLowerCase() == 'true',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'storage_path': storagePath,
        'file_name': fileName,
        'sort_order': sortOrder,
        'is_primary': isPrimary,
      };
}

class PosProductAttributeModel extends PosProductAttribute {
  const PosProductAttributeModel({
    required super.id,
    required super.productId,
    required super.name,
    required super.value,
    super.sortOrder,
  });

  factory PosProductAttributeModel.fromJson(Map<String, dynamic> json) {
    return PosProductAttributeModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      sortOrder: int.tryParse('${json['sort_order'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'name': name,
        'value': value,
        'sort_order': sortOrder,
      };
}

PosProductType parsePosProductType(Object? raw) {
  final value = (raw ?? 'product').toString().toLowerCase();
  return value == 'service' ? PosProductType.service : PosProductType.product;
}

PosDiscountType parsePosDiscountType(Object? raw) {
  switch ((raw ?? '').toString()) {
    case 'fixed_amount':
      return PosDiscountType.fixedAmount;
    case 'fixed_price':
      return PosDiscountType.fixedPrice;
    default:
      return PosDiscountType.percentage;
  }
}

String posDiscountTypeDb(PosDiscountType type) {
  switch (type) {
    case PosDiscountType.percentage:
      return 'percentage';
    case PosDiscountType.fixedAmount:
      return 'fixed_amount';
    case PosDiscountType.fixedPrice:
      return 'fixed_price';
  }
}

class PosProductModel extends PosProduct {
  const PosProductModel({
    required super.id,
    required super.brandId,
    required super.name,
    super.sku,
    super.category,
    super.labelBrand,
    super.productType,
    super.shortDescription,
    super.description,
    super.currentPurchaseCost,
    super.sellingPrice,
    super.mrp,
    super.taxRate,
    super.priceIncludesTax,
    super.trackInventory,
    super.unitOfMeasure,
    super.openingStock,
    super.reorderLevel,
    super.unitsPerPack,
    super.stockOnHand,
    super.barcode,
    super.isActive,
    super.images,
    super.attributes,
    super.createdAt,
    super.updatedAt,
  });

  factory PosProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['pos_product_images'];
    final images = <PosProductImage>[];
    if (rawImages is List) {
      for (final row in rawImages) {
        if (row is Map<String, dynamic>) {
          images.add(PosProductImageModel.fromJson(row));
        }
      }
      images.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    final rawAttrs = json['pos_product_attributes'];
    final attributes = <PosProductAttribute>[];
    if (rawAttrs is List) {
      for (final row in rawAttrs) {
        if (row is Map<String, dynamic>) {
          attributes.add(PosProductAttributeModel.fromJson(row));
        }
      }
      attributes.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return PosProductModel(
      id: (json['id'] ?? '').toString(),
      brandId: (json['brand_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      labelBrand: (json['label_brand'] ?? '').toString(),
      productType: parsePosProductType(json['product_type']),
      shortDescription: (json['short_description'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      currentPurchaseCost:
          double.tryParse('${json['current_purchase_cost'] ?? 0}') ?? 0,
      sellingPrice: double.tryParse('${json['selling_price'] ?? 0}') ?? 0,
      mrp: double.tryParse('${json['mrp'] ?? 0}') ?? 0,
      taxRate: double.tryParse('${json['tax_rate'] ?? 0}') ?? 0,
      priceIncludesTax: json['price_includes_tax'] != false,
      trackInventory: json['track_inventory'] != false,
      unitOfMeasure: (json['unit_of_measure'] ?? 'Piece').toString(),
      openingStock: double.tryParse('${json['opening_stock'] ?? 0}') ?? 0,
      reorderLevel: double.tryParse('${json['reorder_level'] ?? 0}') ?? 0,
      unitsPerPack: double.tryParse('${json['units_per_pack'] ?? 1}') ?? 1,
      stockOnHand: double.tryParse('${json['stock_on_hand'] ?? 0}') ?? 0,
      barcode: (json['barcode'] ?? '').toString(),
      isActive: json['is_active'] == true ||
          json['is_active']?.toString().toLowerCase() == 'true',
      images: images,
      attributes: attributes,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand_id': brandId,
        'name': name,
        'sku': sku,
        'category': category,
        'label_brand': labelBrand,
        'product_type':
            productType == PosProductType.service ? 'service' : 'product',
        'short_description': shortDescription,
        'description': description,
        'current_purchase_cost': currentPurchaseCost,
        'selling_price': sellingPrice,
        'mrp': mrp,
        'tax_rate': taxRate,
        'price_includes_tax': priceIncludesTax,
        'track_inventory': trackInventory,
        'unit_of_measure': unitOfMeasure,
        'opening_stock': openingStock,
        'reorder_level': reorderLevel,
        'units_per_pack': unitsPerPack,
        'stock_on_hand': stockOnHand,
        'barcode': barcode,
        'is_active': isActive,
      };
}

class PosPriceRuleModel extends PosPriceRule {
  const PosPriceRuleModel({
    required super.id,
    required super.brandId,
    required super.productId,
    required super.name,
    required super.discountType,
    required super.discountValue,
    required super.startAt,
    required super.endAt,
    super.finalPrice,
    super.minimumQuantity,
    super.maximumQuantity,
    super.priority,
    super.isActive,
  });

  factory PosPriceRuleModel.fromJson(Map<String, dynamic> json) {
    return PosPriceRuleModel(
      id: (json['id'] ?? '').toString(),
      brandId: (json['brand_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      discountType: parsePosDiscountType(json['discount_type']),
      discountValue: double.tryParse('${json['discount_value'] ?? 0}') ?? 0,
      finalPrice: json['final_price'] == null
          ? null
          : double.tryParse('${json['final_price']}'),
      startAt: DateTime.tryParse((json['start_at'] ?? '').toString()) ??
          DateTime.now(),
      endAt: DateTime.tryParse((json['end_at'] ?? '').toString()) ??
          DateTime.now(),
      minimumQuantity: json['minimum_quantity'] == null
          ? null
          : double.tryParse('${json['minimum_quantity']}'),
      maximumQuantity: json['maximum_quantity'] == null
          ? null
          : double.tryParse('${json['maximum_quantity']}'),
      priority: int.tryParse('${json['priority'] ?? 0}') ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand_id': brandId,
        'product_id': productId,
        'name': name,
        'discount_type': posDiscountTypeDb(discountType),
        'discount_value': discountValue,
        'final_price': finalPrice,
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'minimum_quantity': minimumQuantity,
        'maximum_quantity': maximumQuantity,
        'priority': priority,
        'is_active': isActive,
      };
}

class PosPurchaseItemModel extends PosPurchaseItem {
  const PosPurchaseItemModel({
    required super.id,
    required super.purchaseId,
    required super.productId,
    required super.quantity,
    required super.unitCost,
    super.discount,
    super.tax,
    super.additionalCost,
    super.totalCost,
    super.batchNumber,
    super.expiryDate,
    super.createdAt,
  });

  factory PosPurchaseItemModel.fromJson(Map<String, dynamic> json) {
    return PosPurchaseItemModel(
      id: (json['id'] ?? '').toString(),
      purchaseId: (json['purchase_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      unitCost: double.tryParse('${json['unit_cost'] ?? 0}') ?? 0,
      discount: double.tryParse('${json['discount'] ?? 0}') ?? 0,
      tax: double.tryParse('${json['tax'] ?? 0}') ?? 0,
      additionalCost: double.tryParse('${json['additional_cost'] ?? 0}') ?? 0,
      totalCost: double.tryParse('${json['total_cost'] ?? 0}') ?? 0,
      batchNumber: (json['batch_number'] ?? '').toString(),
      expiryDate: DateTime.tryParse((json['expiry_date'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'quantity': quantity,
        'unit_cost': unitCost,
        'discount': discount,
        'tax': tax,
        'additional_cost': additionalCost,
        'total_cost': totalCost,
        'batch_number': batchNumber,
        'expiry_date': expiryDate?.toIso8601String().split('T').first,
      };
}

class PosPurchaseModel extends PosPurchase {
  const PosPurchaseModel({
    required super.id,
    required super.brandId,
    required super.purchaseDate,
    super.supplierName,
    super.invoiceNumber,
    super.notes,
    super.createdBy,
    super.createdAt,
    super.items,
  });

  factory PosPurchaseModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['pos_purchase_items'];
    final items = <PosPurchaseItem>[];
    if (rawItems is List) {
      for (final row in rawItems) {
        if (row is Map<String, dynamic>) {
          items.add(PosPurchaseItemModel.fromJson(row));
        }
      }
    }
    return PosPurchaseModel(
      id: (json['id'] ?? '').toString(),
      brandId: (json['brand_id'] ?? '').toString(),
      purchaseDate:
          DateTime.tryParse((json['purchase_date'] ?? '').toString()) ??
              DateTime.now(),
      supplierName: (json['supplier_name'] ?? '').toString(),
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand_id': brandId,
        'supplier_name': supplierName,
        'purchase_date': purchaseDate.toIso8601String().split('T').first,
        'invoice_number': invoiceNumber,
        'notes': notes,
        'created_by': createdBy,
      };
}

class PosCommerceAuditModel extends PosCommerceAuditEntry {
  const PosCommerceAuditModel({
    required super.id,
    required super.entityType,
    required super.entityId,
    required super.action,
    super.brandId,
    super.fieldName,
    super.oldValue,
    super.newValue,
    super.reason,
    super.performedByEmail,
    super.performedAt,
  });

  factory PosCommerceAuditModel.fromJson(Map<String, dynamic> json) {
    return PosCommerceAuditModel(
      id: (json['id'] ?? '').toString(),
      entityType: (json['entity_type'] ?? '').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      brandId: json['brand_id']?.toString(),
      action: (json['action'] ?? '').toString(),
      fieldName: (json['field_name'] ?? '').toString(),
      oldValue: (json['old_value'] ?? '').toString(),
      newValue: (json['new_value'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      performedByEmail: (json['performed_by_email'] ?? '').toString(),
      performedAt: DateTime.tryParse((json['performed_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson({String? performedBy}) => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'brand_id': brandId,
        'action': action,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
        'reason': reason,
        'performed_by': performedBy,
        'performed_by_email': performedByEmail,
        'performed_at':
            (performedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };
}
