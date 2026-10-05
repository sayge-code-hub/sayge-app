import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class SetEmployeePhotoFromDocumentUseCase {
  const SetEmployeePhotoFromDocumentUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, Employee>> call({
    required String employeeId,
    required String storagePath,
  }) {
    return _repository.setEmployeePhotoFromDocument(
      employeeId: employeeId,
      storagePath: storagePath,
    );
  }
}
