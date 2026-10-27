import 'package:dartz/dartz.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/billing/billing_access.dart';
import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

/// Signs out remotely and wipes every local auth/session trace.
class SignOutUseCase {
  const SignOutUseCase(this._repository, this._session, this._billing);

  final AuthRepository _repository;
  final AuthSession _session;
  final BillingAccess _billing;

  Future<Either<Failure, Unit>> call() async {
    await _repository.signOut();
    await _session.clear();
    _billing.reset();
    return const Right(unit);
  }
}
