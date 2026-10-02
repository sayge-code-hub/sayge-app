import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/settings_entities.dart';
import '../repositories/settings_repository.dart';

class GetCompanyDetailsUseCase {
  const GetCompanyDetailsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, CompanyDetails>> call() =>
      _repository.getCompanyDetails();
}

class UpdateCompanyDetailsUseCase {
  const UpdateCompanyDetailsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, CompanyDetails>> call(CompanyDetails details) {
    return _repository.updateCompanyDetails(details);
  }
}

class GetRolesUseCase {
  const GetRolesUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, List<AppRole>>> call() => _repository.getRoles();
}

class GetActivityLogUseCase {
  const GetActivityLogUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, List<ActivityLogEntry>>> call({int limit = 200}) {
    return _repository.getActivityLog(limit: limit);
  }
}
