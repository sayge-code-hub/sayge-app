import 'package:dartz/dartz.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Signs out remotely and wipes every local auth/session trace.
class SignOutUseCase {
  const SignOutUseCase(this._repository, this._session);

  final AuthRepository _repository;
  final AuthSession _session;

  Future<Either<Failure, Unit>> call() async {
    await _repository.signOut();
    await _session.clear();
    return const Right(unit);
  }
}
