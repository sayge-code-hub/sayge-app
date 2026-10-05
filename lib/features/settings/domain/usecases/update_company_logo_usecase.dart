import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/settings_entities.dart';
import '../repositories/settings_repository.dart';

class UpdateCompanyLogoUseCase {
  const UpdateCompanyLogoUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Either<Failure, CompanyDetails>> call({
    required String companyId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) {
    return _repository.updateCompanyLogo(
      companyId: companyId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
