import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/cafe_entities.dart';
import '../repositories/cafe_pos_repository.dart';

class GetCafeCategories {
  const GetCafeCategories(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<CafeCategory>>> call(String clientId) =>
      _repo.getCategories(clientId);
}

class UpsertCafeCategory {
  const UpsertCafeCategory(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeCategory>> call(CafeCategory category) =>
      _repo.upsertCategory(category);
}

class DeleteCafeCategory {
  const DeleteCafeCategory(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, void>> call(String id) => _repo.deleteCategory(id);
}

class GetCafeMenuItems {
  const GetCafeMenuItems(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<CafeMenuItem>>> call(
    String clientId, {
    bool availableOnly = false,
  }) =>
      _repo.getMenuItems(clientId, availableOnly: availableOnly);
}

class UpsertCafeMenuItem {
  const UpsertCafeMenuItem(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeMenuItem>> call(CafeMenuItem item) =>
      _repo.upsertMenuItem(item);
}

class DeleteCafeMenuItem {
  const DeleteCafeMenuItem(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, void>> call(String id) => _repo.deleteMenuItem(id);
}

class GetCafeOrders {
  const GetCafeOrders(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<CafeOrder>>> call(
    String clientId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  }) =>
      _repo.getOrders(clientId, day: day, prepStatuses: prepStatuses);
}

class CreateCafeOrder {
  const CreateCafeOrder(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeOrder>> call({
    required String clientId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
  }) =>
      _repo.createOrder(
        clientId: clientId,
        orderType: orderType,
        lines: lines,
        discountAmount: discountAmount,
      );
}

class UpdateCafePrepStatus {
  const UpdateCafePrepStatus(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeOrder>> call({
    required String orderId,
    required CafePrepStatus status,
  }) =>
      _repo.updatePrepStatus(orderId: orderId, status: status);
}

class RecordCafePayment {
  const RecordCafePayment(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeOrder>> call({
    required String orderId,
    required CafePaymentMethod method,
    required double amount,
  }) =>
      _repo.recordPayment(
        orderId: orderId,
        method: method,
        amount: amount,
      );
}

class CancelCafeOrder {
  const CancelCafeOrder(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeOrder>> call({
    required String orderId,
    required String reason,
  }) =>
      _repo.cancelOrder(orderId: orderId, reason: reason);
}

class GetCafeDailyReport {
  const GetCafeDailyReport(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeDailyReport>> call({
    required String clientId,
    required DateTime day,
  }) =>
      _repo.getDailyReport(clientId: clientId, day: day);
}
