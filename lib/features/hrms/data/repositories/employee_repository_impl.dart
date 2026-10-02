import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_datasource.dart';
import '../models/employee_model.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  const EmployeeRepositoryImpl({required this.remoteDataSource});

  final EmployeeRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Employee>>> getEmployees() async {
    try {
      final employees = await remoteDataSource.getEmployees();
      return Right(employees);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Employee>> addEmployee(Employee employee) async {
    try {
      final created = await remoteDataSource.addEmployee(
        EmployeeModel.fromEntity(employee),
      );
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Employee>> updateEmployee(Employee employee) async {
    try {
      final updated = await remoteDataSource.updateEmployee(
        EmployeeModel.fromEntity(employee),
      );
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(ServerFailure());
    }
  }
}
