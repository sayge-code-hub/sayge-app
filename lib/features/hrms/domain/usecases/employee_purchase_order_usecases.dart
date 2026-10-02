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

class GetEmployeePurchaseOrderDownloadUrlUseCase {
  const GetEmployeePurchaseOrderDownloadUrlUseCase(this._repository);

  final EmployeePurchaseOrderRepository _repository;

  Future<Either<Failure, String>> call(EmployeePurchaseOrder po) {
    return _repository.getDownloadUrl(po);
  }
}

// Re-export params for callers.
typedef PoCreateParams = CreateEmployeePurchaseOrderParams;
typedef PoFileBytes = Uint8List;
