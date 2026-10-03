import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pos_entities.dart';

abstract class PosRepository {
  Future<Either<Failure, List<PosBrand>>> getBrands();
  Future<Either<Failure, PosBrand>> getBrand(String id);
  Future<Either<Failure, PosBrand>> upsertBrand(
    PosBrand brand, {
    PosImageUpload? logo,
  });
  Future<Either<Failure, void>> deleteBrand(String id);

  Future<Either<Failure, List<PosProduct>>> getProducts(String brandId);
  Future<Either<Failure, PosProduct>> getProduct(String id);
  Future<Either<Failure, PosProductDetail>> getProductDetail(String id);
  Future<Either<Failure, PosProduct>> upsertProduct({
    required PosProduct product,
    required List<PosImageUpload> images,
    required List<PosProductAttribute> attributes,
    String auditReason,
  });
  Future<Either<Failure, void>> deleteProduct(String id);

  Future<Either<Failure, PosPurchase>> recordPurchase(PosPurchaseDraft draft);
  Future<Either<Failure, PosPriceRule>> upsertPriceRule(PosPriceRule rule);
  Future<Either<Failure, void>> deletePriceRule(String id);

  String publicImageUrl(String storagePath);
}
