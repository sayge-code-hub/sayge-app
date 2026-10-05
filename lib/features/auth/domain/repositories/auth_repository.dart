import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, User?>> restoreSession();

  Future<Either<Failure, Unit>> signOut();

  Future<Either<Failure, User>> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });
}
