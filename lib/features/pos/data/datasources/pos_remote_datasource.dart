import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/pos_entities.dart';
import '../models/pos_models.dart';

abstract class PosRemoteDataSource {
  Future<List<PosBrandModel>> getBrands();
  Future<PosBrandModel> getBrand(String id);
  Future<PosBrandModel> upsertBrand(PosBrand brand, {PosImageUpload? logo});
  Future<void> deleteBrand(String id);

  Future<List<PosProductModel>> getProducts(String brandId);
  Future<PosProductModel> getProduct(String id);
  Future<PosProductDetail> getProductDetail(String id);
  Future<PosProductModel> upsertProduct({
    required PosProduct product,
    required List<PosImageUpload> images,
    required List<PosProductAttribute> attributes,
    String auditReason,
  });
  Future<void> deleteProduct(String id);

  Future<PosPurchase> recordPurchase(PosPurchaseDraft draft);
  Future<PosPriceRule> upsertPriceRule(PosPriceRule rule);
  Future<void> deletePriceRule(String id);

  String publicImageUrl(String storagePath);
}

class PosRemoteDataSourceImpl implements PosRemoteDataSource {
  PosRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _brands = 'pos_brands';
  static const _products = 'pos_products';
  static const _images = 'pos_product_images';
  static const _attributes = 'pos_product_attributes';
  static const _purchases = 'pos_purchases';
  static const _purchaseItems = 'pos_purchase_items';
  static const _priceRules = 'pos_price_rules';
  static const _audit = 'pos_commerce_audit';
  static const _bucket = 'pos-product-images';
  static const _productSelect =
      '*, pos_product_images(*), pos_product_attributes(*)';

  @override
  String publicImageUrl(String storagePath) {
    final path = storagePath.trim();
    if (path.isEmpty) return '';
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  String get _actorEmail =>
      _client.auth.currentUser?.email?.trim() ?? '';

  String? get _actorId => _client.auth.currentUser?.id;

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _writeAudit({
    required String entityType,
    required String entityId,
    required String action,
    String? brandId,
    String fieldName = '',
    String oldValue = '',
    String newValue = '',
    String reason = '',
  }) async {
    try {
      await _client.from(_audit).insert(
            PosCommerceAuditModel(
              id: _id('aud'),
              entityType: entityType,
              entityId: entityId,
              brandId: brandId,
              action: action,
              fieldName: fieldName,
              oldValue: oldValue,
              newValue: newValue,
              reason: reason,
              performedByEmail: _actorEmail,
              performedAt: DateTime.now(),
            ).toJson(performedBy: _actorId),
          );
    } catch (_) {
      // Row-level activity_log still captures table changes.
    }
  }

  String _money(num value) => value.toStringAsFixed(2);

  @override
  Future<List<PosBrandModel>> getBrands() async {
    try {
      final rows =
          await _client.from(_brands).select().order('name', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => PosBrandModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load brands.');
    }
  }

  @override
  Future<PosBrandModel> getBrand(String id) async {
    try {
      final row =
          await _client.from(_brands).select().eq('id', id).single();
      return PosBrandModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load brand.');
    }
  }

  @override
  Future<PosBrandModel> upsertBrand(
    PosBrand brand, {
    PosImageUpload? logo,
  }) async {
    final name = brand.name.trim();
    if (name.isEmpty) {
      throw const ServerException('Brand name is required.');
    }
    final id = brand.id.trim().isEmpty ? _id('brand') : brand.id.trim();
    var logoPath = brand.logoPath.trim();
    String? previousLogo;
    if (brand.id.trim().isNotEmpty) {
      try {
        previousLogo = (await getBrand(id)).logoPath.trim();
      } catch (_) {}
    }

    try {
      if (logo != null && logo.bytes.isNotEmpty) {
        var fileName =
            logo.fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
        if (fileName.isEmpty) fileName = 'logo.jpg';
        final path = '$id/logo_$fileName';
        await _client.storage.from(_bucket).uploadBinary(
              path,
              Uint8List.fromList(logo.bytes),
              fileOptions: FileOptions(
                contentType: logo.mimeType,
                upsert: true,
              ),
            );
        logoPath = path;
      }

      final row = await _client
          .from(_brands)
          .upsert(
            PosBrandModel(
              id: id,
              name: name,
              description: brand.description.trim(),
              logoPath: logoPath,
              isActive: brand.isActive,
            ).toJson(),
          )
          .select()
          .single();

      if (previousLogo != null &&
          previousLogo.isNotEmpty &&
          previousLogo != logoPath) {
        try {
          await _client.storage.from(_bucket).remove([previousLogo]);
        } catch (_) {}
      }
      return PosBrandModel.fromJson(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save brand.');
    }
  }

  @override
  Future<void> deleteBrand(String id) async {
    try {
      PosBrandModel? brand;
      try {
        brand = await getBrand(id);
      } catch (_) {}
      final products = await getProducts(id);
      for (final product in products) {
        await _deleteProductStorage(product);
      }
      final logo = brand?.logoPath.trim() ?? '';
      if (logo.isNotEmpty) {
        try {
          await _client.storage.from(_bucket).remove([logo]);
        } catch (_) {}
      }
      await _client.from(_brands).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete brand.');
    }
  }

  @override
  Future<List<PosProductModel>> getProducts(String brandId) async {
    try {
      final rows = await _client
          .from(_products)
          .select(_productSelect)
          .eq('brand_id', brandId)
          .order('name', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => PosProductModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load products.');
    }
  }

  @override
  Future<PosProductModel> getProduct(String id) async {
    try {
      final row = await _client
          .from(_products)
          .select(_productSelect)
          .eq('id', id)
          .single();
      return PosProductModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load product.');
    }
  }

  @override
  Future<PosProductDetail> getProductDetail(String id) async {
    final product = await getProduct(id);
    try {
      final rulesRows = await _client
          .from(_priceRules)
          .select()
          .eq('product_id', id)
          .order('priority', ascending: false);
      final purchaseRows = await _client
          .from(_purchases)
          .select('*, pos_purchase_items(*)')
          .eq('brand_id', product.brandId)
          .order('purchase_date', ascending: false);
      final auditRows = await _client
          .from(_audit)
          .select()
          .eq('entity_type', 'product')
          .eq('entity_id', id)
          .order('performed_at', ascending: false)
          .limit(100);

      final rules = (rulesRows as List<dynamic>)
          .map((e) => PosPriceRuleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final purchases = (purchaseRows as List<dynamic>)
          .map((e) => PosPurchaseModel.fromJson(e as Map<String, dynamic>))
          .where(
            (p) => p.items.any((item) => item.productId == id),
          )
          .map(
            (p) => PosPurchase(
              id: p.id,
              brandId: p.brandId,
              purchaseDate: p.purchaseDate,
              supplierName: p.supplierName,
              invoiceNumber: p.invoiceNumber,
              notes: p.notes,
              createdBy: p.createdBy,
              createdAt: p.createdAt,
              items: p.items.where((i) => i.productId == id).toList(),
            ),
          )
          .toList();
      final audit = (auditRows as List<dynamic>)
          .map(
            (e) => PosCommerceAuditModel.fromJson(e as Map<String, dynamic>),
          )
          .toList();

      return PosProductDetail(
        product: product,
        priceRules: rules,
        purchases: purchases,
        audit: audit,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load product detail.');
    }
  }

  @override
  Future<PosProductModel> upsertProduct({
    required PosProduct product,
    required List<PosImageUpload> images,
    required List<PosProductAttribute> attributes,
    String auditReason = '',
  }) async {
    final name = product.name.trim();
    final sku = product.sku.trim();
    final category = product.category.trim();
    if (name.isEmpty) {
      throw const ServerException('Product name is required.');
    }
    if (sku.isEmpty) {
      throw const ServerException('SKU is required.');
    }
    if (category.isEmpty) {
      throw const ServerException('Category is required.');
    }
    if (product.brandId.trim().isEmpty) {
      throw const ServerException('Brand is required.');
    }
    if (product.sellingPrice < 0) {
      throw const ServerException('Selling price cannot be negative.');
    }

    final id = product.id.trim().isEmpty ? _id('prod') : product.id.trim();
    final isEdit = product.id.trim().isNotEmpty;
    PosProduct? previous;
    if (isEdit) {
      try {
        previous = await getProduct(id);
      } catch (_) {}
    }

    final isService = product.productType == PosProductType.service;
    final trackInventory = isService ? false : product.trackInventory;
    final stockOnHand = isService
        ? 0.0
        : (isEdit ? product.stockOnHand : product.openingStock);
    final openingStock = isService ? 0.0 : product.openingStock;
    final reorderLevel = (!trackInventory || isService)
        ? 0.0
        : product.reorderLevel;
    final unit = isService
        ? 'Service'
        : (product.unitOfMeasure.trim().isEmpty
            ? 'Piece'
            : product.unitOfMeasure.trim());

    final cleanAttrs = attributes
        .where(
          (a) => a.name.trim().isNotEmpty && a.value.trim().isNotEmpty,
        )
        .toList();

    List<PosProductImage> previousImages = const [];
    if (isEdit) {
      previousImages = previous?.images ?? const [];
    }

    try {
      await _client.from(_products).upsert(
            PosProductModel(
              id: id,
              brandId: product.brandId.trim(),
              name: name,
              sku: sku,
              category: category,
              labelBrand: product.labelBrand.trim(),
              productType: product.productType,
              shortDescription: product.shortDescription.trim(),
              description: product.description.trim(),
              currentPurchaseCost: product.currentPurchaseCost,
              sellingPrice: product.sellingPrice,
              mrp: product.mrp,
              taxRate: product.taxRate,
              priceIncludesTax: product.priceIncludesTax,
              trackInventory: trackInventory,
              unitOfMeasure: unit,
              openingStock: openingStock,
              reorderLevel: reorderLevel,
              unitsPerPack:
                  product.unitsPerPack <= 0 ? 1 : product.unitsPerPack,
              stockOnHand: stockOnHand,
              barcode: product.barcode.trim(),
              isActive: product.isActive,
            ).toJson(),
          );

      // Attributes replace set.
      await _client.from(_attributes).delete().eq('product_id', id);
      if (cleanAttrs.isNotEmpty) {
        await _client.from(_attributes).insert([
          for (var i = 0; i < cleanAttrs.length; i++)
            PosProductAttributeModel(
              id: cleanAttrs[i].id.trim().isEmpty
                  ? _id('attr')
                  : cleanAttrs[i].id.trim(),
              productId: id,
              name: cleanAttrs[i].name.trim(),
              value: cleanAttrs[i].value.trim(),
              sortOrder: i,
            ).toJson(),
        ]);
      }

      final keptPaths = <String>{};
      final imageRows = <Map<String, dynamic>>[];
      for (var i = 0; i < images.length; i++) {
        final upload = images[i];
        String path;
        String fileName;
        String imageId;
        if (upload.isExisting) {
          path = upload.existingPath!.trim();
          fileName = upload.fileName.trim().isEmpty
              ? path.split('/').last
              : upload.fileName.trim();
          imageId = (upload.existingId ?? '').trim().isEmpty
              ? _id('pimg')
              : upload.existingId!.trim();
          keptPaths.add(path);
        } else {
          if (upload.bytes.isEmpty) continue;
          fileName =
              upload.fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
          if (fileName.isEmpty) fileName = 'image_$i.jpg';
          imageId = _id('pimg');
          path = '${product.brandId.trim()}/$id/${imageId}_$fileName';
          await _client.storage.from(_bucket).uploadBinary(
                path,
                Uint8List.fromList(upload.bytes),
                fileOptions: FileOptions(
                  contentType: upload.mimeType,
                  upsert: true,
                ),
              );
          keptPaths.add(path);
        }
        imageRows.add(
          PosProductImageModel(
            id: imageId,
            productId: id,
            storagePath: path,
            fileName: fileName,
            sortOrder: i,
            isPrimary: i == 0,
          ).toJson(),
        );
      }
      await _client.from(_images).delete().eq('product_id', id);
      if (imageRows.isNotEmpty) {
        await _client.from(_images).insert(imageRows);
      }
      for (final old in previousImages) {
        final path = old.storagePath.trim();
        if (path.isNotEmpty && !keptPaths.contains(path)) {
          try {
            await _client.storage.from(_bucket).remove([path]);
          } catch (_) {}
        }
      }

      if (!isEdit) {
        await _writeAudit(
          entityType: 'product',
          entityId: id,
          brandId: product.brandId,
          action: 'Product Created',
          reason: auditReason,
        );
      } else if (previous != null) {
        await _auditProductDiff(
          previous: previous,
          next: product.copyWithIdentity(id: id),
          reason: auditReason,
        );
      }

      return getProduct(id);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('SKU already exists for this brand.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save product.');
    }
  }

  Future<void> _auditProductDiff({
    required PosProduct previous,
    required PosProduct next,
    required String reason,
  }) async {
    Future<void> field(
      String action,
      String field,
      String oldV,
      String newV,
    ) async {
      if (oldV == newV) return;
      await _writeAudit(
        entityType: 'product',
        entityId: next.id,
        brandId: next.brandId,
        action: action,
        fieldName: field,
        oldValue: oldV,
        newValue: newV,
        reason: reason,
      );
    }

    await field(
      'Selling Price Changed',
      'selling_price',
      _money(previous.sellingPrice),
      _money(next.sellingPrice),
    );
    await field(
      'Purchase Cost Changed',
      'current_purchase_cost',
      _money(previous.currentPurchaseCost),
      _money(next.currentPurchaseCost),
    );
    await field(
      'MRP Changed',
      'mrp',
      _money(previous.mrp),
      _money(next.mrp),
    );
    await field(
      'Tax Changed',
      'tax_rate',
      previous.taxRate.toString(),
      next.taxRate.toString(),
    );
    await field(
      'Category Changed',
      'category',
      previous.category,
      next.category,
    );
    await field('SKU Changed', 'sku', previous.sku, next.sku);
    if (previous.isActive && !next.isActive) {
      await _writeAudit(
        entityType: 'product',
        entityId: next.id,
        brandId: next.brandId,
        action: 'Product Deactivated',
        reason: reason,
      );
    } else {
      await _writeAudit(
        entityType: 'product',
        entityId: next.id,
        brandId: next.brandId,
        action: 'Product Updated',
        reason: reason,
      );
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      final product = await getProduct(id);
      await _deleteProductStorage(product);
      await _client.from(_products).delete().eq('id', id);
      await _writeAudit(
        entityType: 'product',
        entityId: id,
        brandId: product.brandId,
        action: 'Product Deleted',
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete product.');
    }
  }

  Future<void> _deleteProductStorage(PosProduct product) async {
    final paths = product.images
        .map((e) => e.storagePath.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;
    try {
      await _client.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  @override
  Future<PosPurchase> recordPurchase(PosPurchaseDraft draft) async {
    if (draft.quantity <= 0) {
      throw const ServerException('Quantity must be greater than zero.');
    }
    if (draft.unitCost < 0) {
      throw const ServerException('Unit cost cannot be negative.');
    }
    final product = await getProduct(draft.productId);
    if (product.isService || !product.trackInventory) {
      throw const ServerException(
        'Inventory purchases require a tracked product.',
      );
    }

    final purchaseId = _id('pur');
    final itemId = _id('puri');
    final lineSubtotal = draft.quantity * draft.unitCost;
    final total = lineSubtotal -
        draft.discount +
        draft.tax +
        draft.additionalCost;

    try {
      await _client.from(_purchases).insert(
            PosPurchaseModel(
              id: purchaseId,
              brandId: draft.brandId,
              purchaseDate: draft.purchaseDate,
              supplierName: draft.supplierName.trim(),
              invoiceNumber: draft.invoiceNumber.trim(),
              notes: draft.notes.trim(),
              createdBy: _actorId,
            ).toJson(),
          );

      await _client.from(_purchaseItems).insert(
            PosPurchaseItemModel(
              id: itemId,
              purchaseId: purchaseId,
              productId: draft.productId,
              quantity: draft.quantity,
              unitCost: draft.unitCost,
              discount: draft.discount,
              tax: draft.tax,
              additionalCost: draft.additionalCost,
              totalCost: total < 0 ? 0 : total,
              batchNumber: draft.batchNumber.trim(),
              expiryDate: draft.expiryDate,
            ).toJson(),
          );

      // MVP costing: last purchase cost. Historical item rows stay immutable.
      final updates = <String, dynamic>{
        'stock_on_hand': product.stockOnHand + draft.quantity,
      };
      if (draft.updateCurrentCost) {
        updates['current_purchase_cost'] = draft.unitCost;
      }
      await _client.from(_products).update(updates).eq('id', draft.productId);

      await _writeAudit(
        entityType: 'product',
        entityId: draft.productId,
        brandId: draft.brandId,
        action: 'Inventory Adjusted',
        fieldName: 'stock_on_hand',
        oldValue: product.stockOnHand.toString(),
        newValue: (product.stockOnHand + draft.quantity).toString(),
        reason: 'Purchase $purchaseId',
      );
      if (draft.updateCurrentCost &&
          product.currentPurchaseCost != draft.unitCost) {
        await _writeAudit(
          entityType: 'product',
          entityId: draft.productId,
          brandId: draft.brandId,
          action: 'Purchase Cost Changed',
          fieldName: 'current_purchase_cost',
          oldValue: _money(product.currentPurchaseCost),
          newValue: _money(draft.unitCost),
          reason: 'Last purchase cost',
        );
      }

      final detail = await getProductDetail(draft.productId);
      return detail.purchases.firstWhere(
        (p) => p.id == purchaseId,
        orElse: () => PosPurchase(
          id: purchaseId,
          brandId: draft.brandId,
          purchaseDate: draft.purchaseDate,
          supplierName: draft.supplierName,
          invoiceNumber: draft.invoiceNumber,
          notes: draft.notes,
          createdBy: _actorId,
          items: [
            PosPurchaseItem(
              id: itemId,
              purchaseId: purchaseId,
              productId: draft.productId,
              quantity: draft.quantity,
              unitCost: draft.unitCost,
              discount: draft.discount,
              tax: draft.tax,
              additionalCost: draft.additionalCost,
              totalCost: total < 0 ? 0 : total,
              batchNumber: draft.batchNumber,
              expiryDate: draft.expiryDate,
            ),
          ],
        ),
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to record purchase.');
    }
  }

  @override
  Future<PosPriceRule> upsertPriceRule(PosPriceRule rule) async {
    if (rule.name.trim().isEmpty) {
      throw const ServerException('Promotion name is required.');
    }
    if (rule.endAt.isBefore(rule.startAt)) {
      throw const ServerException('End date must be on or after start date.');
    }
    final id = rule.id.trim().isEmpty ? _id('promo') : rule.id.trim();
    final isEdit = rule.id.trim().isNotEmpty;
    try {
      final row = await _client
          .from(_priceRules)
          .upsert(
            PosPriceRuleModel(
              id: id,
              brandId: rule.brandId,
              productId: rule.productId,
              name: rule.name.trim(),
              discountType: rule.discountType,
              discountValue: rule.discountValue,
              finalPrice: rule.finalPrice,
              startAt: rule.startAt,
              endAt: rule.endAt,
              minimumQuantity: rule.minimumQuantity,
              maximumQuantity: rule.maximumQuantity,
              priority: rule.priority,
              isActive: rule.isActive,
            ).toJson(),
          )
          .select()
          .single();
      await _writeAudit(
        entityType: 'price_rule',
        entityId: id,
        brandId: rule.brandId,
        action: isEdit ? 'Promotion Updated' : 'Promotion Created',
        newValue: rule.name,
      );
      if (!rule.isActive) {
        await _writeAudit(
          entityType: 'price_rule',
          entityId: id,
          brandId: rule.brandId,
          action: 'Promotion Deactivated',
        );
      }
      return PosPriceRuleModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save promotion.');
    }
  }

  @override
  Future<void> deletePriceRule(String id) async {
    try {
      await _client.from(_priceRules).delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to delete promotion.');
    }
  }
}

extension on PosProduct {
  PosProduct copyWithIdentity({required String id}) {
    return PosProduct(
      id: id,
      brandId: brandId,
      name: name,
      sku: sku,
      category: category,
      labelBrand: labelBrand,
      productType: productType,
      shortDescription: shortDescription,
      description: description,
      currentPurchaseCost: currentPurchaseCost,
      sellingPrice: sellingPrice,
      mrp: mrp,
      taxRate: taxRate,
      priceIncludesTax: priceIncludesTax,
      trackInventory: trackInventory,
      unitOfMeasure: unitOfMeasure,
      openingStock: openingStock,
      reorderLevel: reorderLevel,
      unitsPerPack: unitsPerPack,
      stockOnHand: stockOnHand,
      barcode: barcode,
      isActive: isActive,
      images: images,
      attributes: attributes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
