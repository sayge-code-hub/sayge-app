import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';
import '../repositories/employee_repository.dart';

class AddEmployeeUseCase {
  const AddEmployeeUseCase(this._repository);

  final EmployeeRepository _repository;

  Future<Either<Failure, Employee>> call(Employee employee) {
    return _repository.addEmployee(employee);
  }
}
