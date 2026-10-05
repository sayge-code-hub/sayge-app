import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class UpdateAvatarUseCase {
  const UpdateAvatarUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, User>> call({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) {
    return _repository.updateAvatar(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }
}
