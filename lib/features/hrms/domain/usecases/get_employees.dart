import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class GetEmployeesUseCase {
  const GetEmployeesUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, List<Employee>>> call() {
    return _repository.getEmployees();
  }
}
