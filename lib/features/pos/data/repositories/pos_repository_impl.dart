import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/pos_entities.dart';
import '../../domain/repositories/pos_repository.dart';
import '../datasources/pos_remote_datasource.dart';

class PosRepositoryImpl implements PosRepository {
  const PosRepositoryImpl({required this.remoteDataSource});

  final PosRemoteDataSource remoteDataSource;

  @override
  String publicImageUrl(String storagePath) =>
      remoteDataSource.publicImageUrl(storagePath);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Something went wrong.'));
    }
  }

  @override
  Future<Either<Failure, List<PosBrand>>> getBrands() =>
      _guard(remoteDataSource.getBrands);

  @override
  Future<Either<Failure, PosBrand>> getBrand(String id) =>
      _guard(() => remoteDataSource.getBrand(id));

  @override
  Future<Either<Failure, PosBrand>> upsertBrand(
    PosBrand brand, {
    PosImageUpload? logo,
  }) =>
      _guard(() => remoteDataSource.upsertBrand(brand, logo: logo));

  @override
  Future<Either<Failure, void>> deleteBrand(String id) =>
      _guard(() => remoteDataSource.deleteBrand(id));

  @override
  Future<Either<Failure, List<PosProduct>>> getProducts(String brandId) =>
      _guard(() => remoteDataSource.getProducts(brandId));

  @override
  Future<Either<Failure, PosProduct>> getProduct(String id) =>
      _guard(() => remoteDataSource.getProduct(id));

  @override
  Future<Either<Failure, PosProductDetail>> getProductDetail(String id) =>
      _guard(() => remoteDataSource.getProductDetail(id));

  @override
  Future<Either<Failure, PosProduct>> upsertProduct({
    required PosProduct product,
    required List<PosImageUpload> images,
    required List<PosProductAttribute> attributes,
    String auditReason = '',
  }) =>
      _guard(
        () => remoteDataSource.upsertProduct(
          product: product,
          images: images,
          attributes: attributes,
          auditReason: auditReason,
        ),
      );

  @override
  Future<Either<Failure, void>> deleteProduct(String id) =>
      _guard(() => remoteDataSource.deleteProduct(id));

  @override
  Future<Either<Failure, PosPurchase>> recordPurchase(
    PosPurchaseDraft draft,
  ) =>
      _guard(() => remoteDataSource.recordPurchase(draft));

  @override
  Future<Either<Failure, PosPriceRule>> upsertPriceRule(PosPriceRule rule) =>
      _guard(() => remoteDataSource.upsertPriceRule(rule));

  @override
  Future<Either<Failure, void>> deletePriceRule(String id) =>
      _guard(() => remoteDataSource.deletePriceRule(id));
}
