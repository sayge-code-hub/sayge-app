import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class RehireEmployeeUseCase {
  const RehireEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, Employee>> call({
    required String employeeId,
    DateTime? dateOfJoining,
  }) {
    return _repository.rehireEmployee(
      employeeId: employeeId,
      dateOfJoining: dateOfJoining,
    );
  }
}
