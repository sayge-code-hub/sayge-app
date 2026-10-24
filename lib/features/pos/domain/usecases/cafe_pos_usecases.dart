import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/cafe_entities.dart';
import '../repositories/cafe_pos_repository.dart';

class GetCafes {
  const GetCafes(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<Cafe>>> call() => _repo.getCafes();
}

class UpsertCafe {
  const UpsertCafe(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, Cafe>> call(Cafe cafe) => _repo.upsertCafe(cafe);
}

class UploadCafeGuestLogo {
  const UploadCafeGuestLogo(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, Cafe>> call({
    required String cafeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) =>
      _repo.uploadGuestLogo(
        cafeId: cafeId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
}

class ClearCafeGuestLogo {
  const ClearCafeGuestLogo(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, Cafe>> call(String cafeId) =>
      _repo.clearGuestLogo(cafeId);
}

class GetCafeCategories {
  const GetCafeCategories(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<CafeCategory>>> call(String cafeId) =>
      _repo.getCategories(cafeId);
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
    String cafeId, {
    bool availableOnly = false,
  }) =>
      _repo.getMenuItems(cafeId, availableOnly: availableOnly);
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
    String cafeId, {
    DateTime? day,
    List<CafePrepStatus>? prepStatuses,
  }) =>
      _repo.getOrders(cafeId, day: day, prepStatuses: prepStatuses);
}

class CreateCafeOrder {
  const CreateCafeOrder(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeOrder>> call({
    required String cafeId,
    required CafeOrderType orderType,
    required List<CafeCartLine> lines,
    double discountAmount = 0,
    String? couponId,
    String couponCode = '',
    String tableNo = '',
  }) =>
      _repo.createOrder(
        cafeId: cafeId,
        orderType: orderType,
        lines: lines,
        discountAmount: discountAmount,
        couponId: couponId,
        couponCode: couponCode,
        tableNo: tableNo,
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
    required String cafeId,
    required DateTime day,
  }) =>
      _repo.getDailyReport(cafeId: cafeId, day: day);
}

class GetCafeCoupons {
  const GetCafeCoupons(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, List<CafeCoupon>>> call(String cafeId) =>
      _repo.getCoupons(cafeId);
}

class LookupCafeCoupon {
  const LookupCafeCoupon(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeCoupon?>> call({
    required String cafeId,
    required String code,
  }) =>
      _repo.lookupCoupon(cafeId: cafeId, code: code);
}

class UpsertCafeCoupon {
  const UpsertCafeCoupon(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, CafeCoupon>> call(CafeCoupon coupon) =>
      _repo.upsertCoupon(coupon);
}

class DeleteCafeCoupon {
  const DeleteCafeCoupon(this._repo);
  final CafePosRepository _repo;
  Future<Either<Failure, void>> call(String id) => _repo.deleteCoupon(id);
}
