import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class ExitEmployeeUseCase {
  const ExitEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, Employee>> call({
    required String employeeId,
    required DateTime dateOfExit,
  }) {
    return _repository.exitEmployee(
      employeeId: employeeId,
      dateOfExit: dateOfExit,
    );
  }
}
