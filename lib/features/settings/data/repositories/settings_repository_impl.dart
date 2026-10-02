import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/settings_entities.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl({required this.remoteDataSource});

  final SettingsRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, CompanyDetails>> getCompanyDetails() async {
    try {
      return Right(await remoteDataSource.getCompanyDetails());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load company details.'));
    }
  }

  @override
  Future<Either<Failure, CompanyDetails>> updateCompanyDetails(
    CompanyDetails details,
  ) async {
    try {
      return Right(await remoteDataSource.updateCompanyDetails(details));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to save company details.'));
    }
  }

  @override
  Future<Either<Failure, List<AppRole>>> getRoles() async {
    try {
      return Right(await remoteDataSource.getRoles());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load roles.'));
    }
  }

  @override
  Future<Either<Failure, List<ActivityLogEntry>>> getActivityLog({
    int limit = 200,
  }) async {
    try {
      return Right(await remoteDataSource.getActivityLog(limit: limit));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (_) {
      return const Left(NetworkFailure('Failed to load activity ledger.'));
    }
  }
}
