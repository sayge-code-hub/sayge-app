import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/employee_purchase_order.dart';
import '../../domain/repositories/employee_purchase_order_repository.dart';
import '../datasources/employee_purchase_order_remote_datasource.dart';

class EmployeePurchaseOrderRepositoryImpl
    implements EmployeePurchaseOrderRepository {
  const EmployeePurchaseOrderRepositoryImpl({required this.remoteDataSource});

  final EmployeePurchaseOrderRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<EmployeePurchaseOrder>>> getForEmployee(
    String employeeId,
  ) async {
    try {
      final list = await remoteDataSource.getForEmployee(employeeId);
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load purchase orders.'));
    }
  }

  @override
  Future<Either<Failure, List<EmployeePurchaseOrder>>> getAll() async {
    try {
      final list = await remoteDataSource.getAll();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load purchase orders.'));
    }
  }

  @override
  Future<Either<Failure, EmployeePurchaseOrder>> create(
    CreateEmployeePurchaseOrderParams params,
  ) async {
    try {
      final created = await remoteDataSource.create(
        employeeId: params.employeeId,
        poNumber: params.poNumber,
        startDate: params.startDate,
        endDate: params.endDate,
        fileName: params.fileName,
        fileBytes: params.fileBytes,
        mimeType: params.mimeType,
      );
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to save purchase order.'));
    }
  }

  @override
  Future<Either<Failure, String>> getDownloadUrl(
    EmployeePurchaseOrder po,
  ) async {
    try {
      final url = await remoteDataSource.getDownloadUrl(po.storagePath);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to get download link.'));
    }
  }
}
