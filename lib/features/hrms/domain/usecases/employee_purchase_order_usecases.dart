import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee_purchase_order.dart';
import '../repositories/employee_purchase_order_repository.dart';

class GetEmployeePurchaseOrdersUseCase {
  const GetEmployeePurchaseOrdersUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, List<EmployeePurchaseOrder>>> call(String employeeId) {
    return _repository.getForEmployee(employeeId);
  }
}

class GetAllEmployeePurchaseOrdersUseCase {
  const GetAllEmployeePurchaseOrdersUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, List<EmployeePurchaseOrder>>> call() {
    return _repository.getAll();
  }
}

class CreateEmployeePurchaseOrderUseCase {
  const CreateEmployeePurchaseOrderUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, EmployeePurchaseOrder>> call(
    CreateEmployeePurchaseOrderParams params,
  ) {
    return _repository.create(params);
  }
}

class UpdateEmployeePurchaseOrderUseCase {
  const UpdateEmployeePurchaseOrderUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, EmployeePurchaseOrder>> call(
    UpdateEmployeePurchaseOrderParams params,
  ) {
    return _repository.update(params);
  }
}

class DeleteEmployeePurchaseOrderUseCase {
  const DeleteEmployeePurchaseOrderUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, Unit>> call(String id) {
    return _repository.delete(id);
  }
}

class GetEmployeePurchaseOrderDownloadUrlUseCase {
  const GetEmployeePurchaseOrderDownloadUrlUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, String>> call(EmployeePurchaseOrder po) {
    return _repository.getDownloadUrl(po);
  }
}

// Re-export params for callers.
typedef PoCreateParams = CreateEmployeePurchaseOrderParams;
typedef PoUpdateParams = UpdateEmployeePurchaseOrderParams;
typedef PoFileBytes = Uint8List;
