import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeePhotoUseCase {
  const UpdateEmployeePhotoUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, Employee>> call({
    required String employeeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) {
    return _repository.updateEmployeePhoto(
      employeeId: employeeId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
