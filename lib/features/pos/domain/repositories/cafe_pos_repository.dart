import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/cafe_entities.dart';

abstract class CafePosRepository {
  Future<Either<Failure, List<CafeCategory>>> getCategories(String clientId);

  Future<Either<Failure, CafeCategory>> upsertCategory(CafeCategory category);

  Future<Either<Failure, void>> deleteCategory(String id);

  Future<Either<Failure, List<CafeMenuItem>>> getMenuItems(
    String clientId, {
    bool availableOnly = false,
  });

  Future<Either<Failure, CafeMenuItem>> upsertMenuItem(CafeMenuItem item);

  Future<Either<Failure, void>> deleteMenuItem(String id);

  Future<Either<Failure, List<CafeOrder>>> getOrders(
    String clientId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  });

  Future<Either<Failure, CafeOrder>> getOrder(String orderId);

  Future<Either<Failure, CafeOrder>> createOrder({
    required String clientId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
  });

  Future<Either<Failure, CafeOrder>> updatePrepStatus({
    required String orderId,
    required CafePrepStatus status,
  });

  Future<Either<Failure, CafeOrder>> recordPayment({
    required String orderId,
    required CafePaymentMethod method,
    required double amount,
  });

  Future<Either<Failure, CafeOrder>> cancelOrder({
    required String orderId,
    required String reason,
  });

  Future<Either<Failure, CafeDailyReport>> getDailyReport({
    required String clientId,
    required DateTime day,
  });
}
