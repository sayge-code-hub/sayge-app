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
  Future<Either<Failure, List<CafeCategory>>> getCategories(String clientId) =>
      _guard(() => remoteDataSource.getCategories(clientId));

  @override
  Future<Either<Failure, CafeCategory>> upsertCategory(CafeCategory category) =>
      _guard(() => remoteDataSource.upsertCategory(category));

  @override
  Future<Either<Failure, void>> deleteCategory(String id) =>
      _guard(() => remoteDataSource.deleteCategory(id));

  @override
  Future<Either<Failure, List<CafeMenuItem>>> getMenuItems(
    String clientId, {
    bool availableOnly = false,
  }) =>
      _guard(
        () => remoteDataSource.getMenuItems(
          clientId,
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
    String clientId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  }) =>
      _guard(
        () => remoteDataSource.getOrders(
          clientId,
          day: day,
          prepStatuses: prepStatuses,
        ),
      );

  @override
  Future<Either<Failure, CafeOrder>> getOrder(String orderId) =>
      _guard(() => remoteDataSource.getOrder(orderId));

  @override
  Future<Either<Failure, CafeOrder>> createOrder({
    required String clientId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
  }) =>
      _guard(
        () => remoteDataSource.createOrder(
          clientId: clientId,
          orderType: orderType,
          lines: lines,
          discountAmount: discountAmount,
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
  Future<Either<Failure, CafeDailyReport>> getDailyReport({
    required String clientId,
    required DateTime day,
  }) =>
      _guard(
        () => remoteDataSource.getDailyReport(clientId: clientId, day: day),
      );
}
