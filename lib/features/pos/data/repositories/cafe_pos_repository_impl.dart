import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/cafe_entities.dart';
import '../../domain/repositories/cafe_pos_repository.dart';
import '../datasources/cafe_pos_remote_datasource.dart';

class CafePosRepositoryImpl implements CafePosRepository {
  const CafePosRepositoryImpl({required this.remoteDataSource});

  final CafePosRemoteDataSource remoteDataSource;

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Cafe POS request failed.'));
    }
  }

  @override
  Future<Either<Failure, List<Cafe>>> getCafes() =>
      _guard(() => remoteDataSource.getCafes());

  @override
  Future<Either<Failure, Cafe>> upsertCafe(Cafe cafe) =>
      _guard(() => remoteDataSource.upsertCafe(cafe));

  @override
  Future<Either<Failure, Cafe>> uploadGuestLogo({
    required String cafeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) =>
      _guard(
        () => remoteDataSource.uploadGuestLogo(
          cafeId: cafeId,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        ),
      );

  @override
  Future<Either<Failure, Cafe>> clearGuestLogo(String cafeId) =>
      _guard(() => remoteDataSource.clearGuestLogo(cafeId));

  @override
  Future<Either<Failure, List<CafeCategory>>> getCategories(String cafeId) =>
      _guard(() => remoteDataSource.getCategories(cafeId));

  @override
  Future<Either<Failure, CafeCategory>> upsertCategory(CafeCategory category) =>
      _guard(() => remoteDataSource.upsertCategory(category));

  @override
  Future<Either<Failure, void>> deleteCategory(String id) =>
      _guard(() => remoteDataSource.deleteCategory(id));

  @override
  Future<Either<Failure, List<CafeMenuItem>>> getMenuItems(
    String cafeId, {
    bool availableOnly = false,
  }) =>
      _guard(
        () => remoteDataSource.getMenuItems(
          cafeId,
          availableOnly: availableOnly,
        ),
      );

  @override
  Future<Either<Failure, CafeMenuItem>> upsertMenuItem(CafeMenuItem item) =>
      _guard(() => remoteDataSource.upsertMenuItem(item));

  @override
  Future<Either<Failure, void>> deleteMenuItem(String id) =>
      _guard(() => remoteDataSource.deleteMenuItem(id));

  @override
  Future<Either<Failure, List<CafeOrder>>> getOrders(
    String cafeId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  }) =>
      _guard(
        () => remoteDataSource.getOrders(
          cafeId,
          day: day,
          prepStatuses: prepStatuses,
        ),
      );

  @override
  Future<Either<Failure, CafeOrder>> getOrder(String orderId) =>
      _guard(() => remoteDataSource.getOrder(orderId));

  @override
  Future<Either<Failure, CafeOrder>> createOrder({
    required String cafeId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
    String? couponId,
    String couponCode = '',
    String tableNo = '',
  }) =>
      _guard(
        () => remoteDataSource.createOrder(
          cafeId: cafeId,
          orderType: orderType,
          lines: lines,
          discountAmount: discountAmount,
          couponId: couponId,
          couponCode: couponCode,
          tableNo: tableNo,
        ),
      );

  @override
  Future<Either<Failure, CafeOrder>> updatePrepStatus({
    required String orderId,
    required CafePrepStatus status,
  }) =>
      _guard(
        () => remoteDataSource.updatePrepStatus(
          orderId: orderId,
          status: status,
        ),
      );

  @override
  Future<Either<Failure, CafeOrder>> recordPayment({
    required String orderId,
    required CafePaymentMethod method,
    required double amount,
  }) =>
      _guard(
        () => remoteDataSource.recordPayment(
          orderId: orderId,
          method: method,
          amount: amount,
        ),
      );

  @override
  Future<Either<Failure, CafeOrder>> cancelOrder({
    required String orderId,
    required String reason,
  }) =>
      _guard(
        () => remoteDataSource.cancelOrder(orderId: orderId, reason: reason),
      );

  @override
  Future<Either<Failure, void>> clearCafeOrders(String cafeId) =>
      _guard(() => remoteDataSource.clearCafeOrders(cafeId));

  @override
  Future<Either<Failure, CafeDailyReport>> getDailyReport({
    required String cafeId,
    required DateTime day,
  }) =>
      _guard(
        () => remoteDataSource.getDailyReport(cafeId: cafeId, day: day),
      );

  @override
  Future<Either<Failure, List<CafeCoupon>>> getCoupons(String cafeId) =>
      _guard(() => remoteDataSource.getCoupons(cafeId));

  @override
  Future<Either<Failure, CafeCoupon?>> lookupCoupon({
    required String cafeId,
    required String code,
  }) =>
      _guard(
        () => remoteDataSource.lookupCoupon(cafeId: cafeId, code: code),
      );

  @override
  Future<Either<Failure, CafeCoupon>> upsertCoupon(CafeCoupon coupon) =>
      _guard(() => remoteDataSource.upsertCoupon(coupon));

  @override
  Future<Either<Failure, void>> deleteCoupon(String id) =>
      _guard(() => remoteDataSource.deleteCoupon(id));
}
