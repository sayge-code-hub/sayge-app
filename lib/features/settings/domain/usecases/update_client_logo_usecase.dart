import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class UpdateClientLogoUseCase {
  const UpdateClientLogoUseCase(this._repository);

  final ClientRepository _repository;

  Future<Either<Failure, Client>> call({
    required String id,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) {
    return _repository.updateClientLogo(
      id: id,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
