import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoice_remote_datasource.dart';
import '../models/invoice_model.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  const InvoiceRepositoryImpl({required this.remoteDataSource});

  final InvoiceRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, List<Invoice>>> getInvoices() async {
    try {
      final list = await remoteDataSource.getInvoices();
      return Right(list);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load invoices.'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> createInvoice(Invoice invoice) async {
    try {
      final created = await remoteDataSource.createInvoice(
        InvoiceModel.fromEntity(invoice),
      );
      return Right(created);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to create invoice.'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice(Invoice invoice) async {
    try {
      final updated = await remoteDataSource.updateInvoice(
        InvoiceModel.fromEntity(invoice),
      );
      return Right(updated);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to update invoice.'));
    }
  }
}
