import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/employee.dart';

abstract class EmployeeRepository {
  Future<Either<Failure, List<Employee>>> getEmployees();

  Future<Either<Failure, Employee>> addEmployee(Employee employee);

  Future<Either<Failure, Employee>> updateEmployee(Employee employee);

  Future<Either<Failure, Employee>> exitEmployee({
    required String employeeId,
    required DateTime dateOfExit,
  });
}
