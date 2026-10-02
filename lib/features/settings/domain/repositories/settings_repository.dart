import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/settings_entities.dart';

abstract class SettingsRepository {
  Future<Either<Failure, CompanyDetails>> getCompanyDetails();

  Future<Either<Failure, CompanyDetails>> updateCompanyDetails(
    CompanyDetails details,
  );

  Future<Either<Failure, List<AppRole>>> getRoles();

  Future<Either<Failure, List<ActivityLogEntry>>> getActivityLog({
    int limit = 200,
  });
}
