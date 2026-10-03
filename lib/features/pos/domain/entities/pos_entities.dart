import 'package:equatable/equatable.dart';

class PosBrand extends Equatable {
  const PosBrand({
    required this.id,
    required this.name,
    this.description = '',
    this.logoPath = '',
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String logoPath;
  final bool isActive;
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [id, name, description, logoPath, isActive, createdAt];
}

class PosProductImage extends Equatable {
  const PosProductImage({
    required this.id,
    required this.productId,
    required this.storagePath,
    this.fileName = '',
    this.sortOrder = 0,
    this.isPrimary = false,
  });

  final String id;
  final String productId;
  final String storagePath;
  final String fileName;
  final int sortOrder;
  final bool isPrimary;

  @override
  List<Object?> get props =>
      [id, productId, storagePath, fileName, sortOrder, isPrimary];
}

class PosProductAttribute extends Equatable {
  const PosProductAttribute({
    required this.id,
    required this.productId,
    required this.name,
    required this.value,
    this.sortOrder = 0,
  });

  final String id;
  final String productId;
  final String name;
  final String value;
  final int sortOrder;

  @override
  List<Object?> get props => [id, productId, name, value, sortOrder];
}

enum PosProductType { product, service }

enum PosDiscountType { percentage, fixedAmount, fixedPrice }

class PosProduct extends Equatable {
  const PosProduct({
    required this.id,
    required this.brandId,
    required this.name,
    this.sku = '',
    this.category = '',
    this.labelBrand = '',
    this.productType = PosProductType.product,
    this.shortDescription = '',
    this.description = '',
    this.currentPurchaseCost = 0,
    this.sellingPrice = 0,
    this.mrp = 0,
    this.taxRate = 0,
    this.priceIncludesTax = true,
    this.trackInventory = true,
    this.unitOfMeasure = 'Piece',
    this.openingStock = 0,
    this.reorderLevel = 0,
    this.unitsPerPack = 1,
    this.stockOnHand = 0,
    this.barcode = '',
    this.isActive = true,
    this.images = const [],
    this.attributes = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String brandId;
  final String name;
  final String sku;
  final String category;
  final String labelBrand;
  final PosProductType productType;
  final String shortDescription;
  final String description;
  final double currentPurchaseCost;
  final double sellingPrice;
  final double mrp;
  final double taxRate;
  final bool priceIncludesTax;
  final bool trackInventory;
  final String unitOfMeasure;
  final double openingStock;
  final double reorderLevel;
  final double unitsPerPack;
  final double stockOnHand;
  final String barcode;
  final bool isActive;
  final List<PosProductImage> images;
  final List<PosProductAttribute> attributes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isService => productType == PosProductType.service;

  String? get primaryImagePath {
    if (images.isEmpty) return null;
    for (final image in images) {
      if (image.isPrimary) return image.storagePath;
    }
    return images.first.storagePath;
  }

  @override
  List<Object?> get props => [
        id,
        brandId,
        name,
        sku,
        category,
        labelBrand,
        productType,
        shortDescription,
        description,
        currentPurchaseCost,
        sellingPrice,
        mrp,
        taxRate,
        priceIncludesTax,
        trackInventory,
        unitOfMeasure,
        openingStock,
        reorderLevel,
        unitsPerPack,
        stockOnHand,
        barcode,
        isActive,
        images,
        attributes,
        createdAt,
        updatedAt,
      ];
}

class PosPriceRule extends Equatable {
  const PosPriceRule({
    required this.id,
    required this.brandId,
    required this.productId,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.startAt,
    required this.endAt,
    this.finalPrice,
    this.minimumQuantity,
    this.maximumQuantity,
    this.priority = 0,
    this.isActive = true,
  });

  final String id;
  final String brandId;
  final String productId;
  final String name;
  final PosDiscountType discountType;
  final double discountValue;
  final double? finalPrice;
  final DateTime startAt;
  final DateTime endAt;
  final double? minimumQuantity;
  final double? maximumQuantity;
  final int priority;
  final bool isActive;

  bool isCurrentlyActive([DateTime? at]) {
    if (!isActive) return false;
    final now = at ?? DateTime.now();
    return !now.isBefore(startAt) && !now.isAfter(endAt);
  }

  double resolvedPrice(double baseSellingPrice) {
    switch (discountType) {
      case PosDiscountType.percentage:
        return (baseSellingPrice * (1 - (discountValue / 100)))
            .clamp(0, double.infinity)
            .toDouble();
      case PosDiscountType.fixedAmount:
        return (baseSellingPrice - discountValue)
            .clamp(0, double.infinity)
            .toDouble();
      case PosDiscountType.fixedPrice:
        return (finalPrice ?? discountValue).clamp(0, double.infinity).toDouble();
    }
  }

  @override
  List<Object?> get props => [
        id,
        brandId,
        productId,
        name,
        discountType,
        discountValue,
        finalPrice,
        startAt,
        endAt,
        minimumQuantity,
        maximumQuantity,
        priority,
        isActive,
      ];
}

class PosPurchaseItem extends Equatable {
  const PosPurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    this.discount = 0,
    this.tax = 0,
    this.additionalCost = 0,
    this.totalCost = 0,
    this.batchNumber = '',
    this.expiryDate,
    this.createdAt,
  });

  final String id;
  final String purchaseId;
  final String productId;
  final double quantity;
  final double unitCost;
  final double discount;
  final double tax;
  final double additionalCost;
  final double totalCost;
  final String batchNumber;
  final DateTime? expiryDate;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        purchaseId,
        productId,
        quantity,
        unitCost,
        discount,
        tax,
        additionalCost,
        totalCost,
        batchNumber,
        expiryDate,
        createdAt,
      ];
}

class PosPurchase extends Equatable {
  const PosPurchase({
    required this.id,
    required this.brandId,
    required this.purchaseDate,
    this.supplierName = '',
    this.invoiceNumber = '',
    this.notes = '',
    this.createdBy,
    this.createdAt,
    this.items = const [],
  });

  final String id;
  final String brandId;
  final DateTime purchaseDate;
  final String supplierName;
  final String invoiceNumber;
  final String notes;
  final String? createdBy;
  final DateTime? createdAt;
  final List<PosPurchaseItem> items;

  @override
  List<Object?> get props => [
        id,
        brandId,
        purchaseDate,
        supplierName,
        invoiceNumber,
        notes,
        createdBy,
        createdAt,
        items,
      ];
}

class PosCommerceAuditEntry extends Equatable {
  const PosCommerceAuditEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.brandId,
    this.fieldName = '',
    this.oldValue = '',
    this.newValue = '',
    this.reason = '',
    this.performedByEmail = '',
    this.performedAt,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String? brandId;
  final String action;
  final String fieldName;
  final String oldValue;
  final String newValue;
  final String reason;
  final String performedByEmail;
  final DateTime? performedAt;

  @override
  List<Object?> get props => [
        id,
        entityType,
        entityId,
        brandId,
        action,
        fieldName,
        oldValue,
        newValue,
        reason,
        performedByEmail,
        performedAt,
      ];
}

class PosProductDetail extends Equatable {
  const PosProductDetail({
    required this.product,
    this.priceRules = const [],
    this.purchases = const [],
    this.audit = const [],
  });

  final PosProduct product;
  final List<PosPriceRule> priceRules;
  final List<PosPurchase> purchases;
  final List<PosCommerceAuditEntry> audit;

  double get effectiveSellingPrice =>
      PosPricing.resolveSellingPrice(
        baseSellingPrice: product.sellingPrice,
        rules: priceRules,
      );

  @override
  List<Object?> get props => [product, priceRules, purchases, audit];
}

/// Pricing resolution order: active promotion → base selling price.
/// Extensible later for customer / quantity rules.
abstract final class PosPricing {
  static double resolveSellingPrice({
    required double baseSellingPrice,
    required List<PosPriceRule> rules,
    DateTime? at,
    double? quantity,
  }) {
    final now = at ?? DateTime.now();
    final active = rules.where((rule) {
      if (!rule.isCurrentlyActive(now)) return false;
      if (quantity != null) {
        if (rule.minimumQuantity != null && quantity < rule.minimumQuantity!) {
          return false;
        }
        if (rule.maximumQuantity != null && quantity > rule.maximumQuantity!) {
          return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    if (active.isEmpty) return baseSellingPrice;
    return active.first.resolvedPrice(baseSellingPrice);
  }
}

class PosImageUpload {
  const PosImageUpload({
    required this.fileName,
    required this.bytes,
    this.mimeType = 'image/jpeg',
    this.existingPath,
    this.existingId,
  });

  final String fileName;
  final List<int> bytes;
  final String mimeType;
  final String? existingPath;
  final String? existingId;

  bool get isExisting =>
      (existingPath ?? '').trim().isNotEmpty && bytes.isEmpty;
}

class PosPurchaseDraft {
  const PosPurchaseDraft({
    required this.brandId,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.purchaseDate,
    this.supplierName = '',
    this.invoiceNumber = '',
    this.discount = 0,
    this.tax = 0,
    this.additionalCost = 0,
    this.batchNumber = '',
    this.expiryDate,
    this.notes = '',
    this.updateCurrentCost = true,
  });

  final String brandId;
  final String productId;
  final double quantity;
  final double unitCost;
  final DateTime purchaseDate;
  final String supplierName;
  final String invoiceNumber;
  final double discount;
  final double tax;
  final double additionalCost;
  final String batchNumber;
  final DateTime? expiryDate;
  final String notes;
  final bool updateCurrentCost;
}

abstract final class PosUnits {
  static const values = <String>[
    'Piece',
    'Bottle',
    'Box',
    'Pack',
    'Kg',
    'Gram',
    'Litre',
    'Ml',
    'Meter',
    'Set',
    'Service',
    'Other',
  ];
}
