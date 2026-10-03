import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pos_entities.dart';
import '../repositories/pos_repository.dart';

class GetPosBrandsUseCase {
  const GetPosBrandsUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, List<PosBrand>>> call() => _repository.getBrands();
}

class GetPosBrandUseCase {
  const GetPosBrandUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosBrand>> call(String id) =>
      _repository.getBrand(id);
}

class UpsertPosBrandUseCase {
  const UpsertPosBrandUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosBrand>> call(
    PosBrand brand, {
    PosImageUpload? logo,
  }) =>
      _repository.upsertBrand(brand, logo: logo);
}

class DeletePosBrandUseCase {
  const DeletePosBrandUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, void>> call(String id) =>
      _repository.deleteBrand(id);
}

class GetPosProductsUseCase {
  const GetPosProductsUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, List<PosProduct>>> call(String brandId) =>
      _repository.getProducts(brandId);
}

class GetPosProductUseCase {
  const GetPosProductUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosProduct>> call(String id) =>
      _repository.getProduct(id);
}

class GetPosProductDetailUseCase {
  const GetPosProductDetailUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosProductDetail>> call(String id) =>
      _repository.getProductDetail(id);
}

class UpsertPosProductUseCase {
  const UpsertPosProductUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosProduct>> call({
    required PosProduct product,
    required List<PosImageUpload> images,
    required List<PosProductAttribute> attributes,
    String auditReason = '',
  }) =>
      _repository.upsertProduct(
        product: product,
        images: images,
        attributes: attributes,
        auditReason: auditReason,
      );
}

class DeletePosProductUseCase {
  const DeletePosProductUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, void>> call(String id) =>
      _repository.deleteProduct(id);
}

class RecordPosPurchaseUseCase {
  const RecordPosPurchaseUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosPurchase>> call(PosPurchaseDraft draft) =>
      _repository.recordPurchase(draft);
}

class UpsertPosPriceRuleUseCase {
  const UpsertPosPriceRuleUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, PosPriceRule>> call(PosPriceRule rule) =>
      _repository.upsertPriceRule(rule);
}

class DeletePosPriceRuleUseCase {
  const DeletePosPriceRuleUseCase(this._repository);
  final PosRepository _repository;
  Future<Either<Failure, void>> call(String id) =>
      _repository.deletePriceRule(id);
}

class PosPublicImageUrlUseCase {
  const PosPublicImageUrlUseCase(this._repository);
  final PosRepository _repository;
  String call(String storagePath) => _repository.publicImageUrl(storagePath);
}
