import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

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

  Future<Either<Failure, Employee>> updateEmployeePhoto({
    required String employeeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });

  Future<Either<Failure, Employee>> setEmployeePhotoFromDocument({
    required String employeeId,
    required String storagePath,
  });
}
