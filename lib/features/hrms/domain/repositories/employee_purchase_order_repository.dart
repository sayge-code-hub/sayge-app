import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee_purchase_order.dart';

class CreateEmployeePurchaseOrderParams {
  const CreateEmployeePurchaseOrderParams({
    required this.employeeId,
    required this.poNumber,
    required this.startDate,
    required this.endDate,
    required this.fileName,
    required this.fileBytes,
    this.mimeType = 'application/pdf',
  });

  final String employeeId;
  final String poNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String fileName;
  final Uint8List fileBytes;
  final String mimeType;
}

abstract class EmployeePurchaseOrderRepository {
  Future<Either<Failure, List<EmployeePurchaseOrder>>> getForEmployee(
    String employeeId,
  );

  Future<Either<Failure, List<EmployeePurchaseOrder>>> getAll();

  Future<Either<Failure, EmployeePurchaseOrder>> create(
    CreateEmployeePurchaseOrderParams params,
  );

  Future<Either<Failure, String>> getDownloadUrl(EmployeePurchaseOrder po);
}
