import 'package:flutter/foundation.dart';

import '../../features/auth/domain/entities/user.dart';
import 'auth_local_storage.dart';

/// Holds the signed-in user so go_router can redirect and shells can read it.
///
/// Profile is persisted via [AuthLocalStorage] (SharedPreferences).
class AuthSession extends ChangeNotifier {
  AuthSession({
    required AuthLocalStorage storage,
    User? initialUser,
    bool needsPasswordSetup = false,
  })  : _storage = storage,
        _user = initialUser,
        _needsPasswordSetup = needsPasswordSetup;

  final AuthLocalStorage _storage;
  User? _user;
  bool _needsPasswordSetup;

  User? get user => _user;

  bool get isAuthenticated => _user != null;

  /// True for invitees until they finish [SetPasswordPage].
  bool get needsPasswordSetup => _needsPasswordSetup;

  Future<void> setUser(
    User user, {
    bool? needsPasswordSetup,
  }) async {
    _user = user;
    if (needsPasswordSetup != null) {
      _needsPasswordSetup = needsPasswordSetup;
    }
    await _storage.saveUser(user);
    notifyListeners();
  }

  Future<void> markPasswordSetupComplete() async {
    _needsPasswordSetup = false;
    notifyListeners();
  }

  Future<void> requirePasswordSetup() async {
    if (_needsPasswordSetup) return;
    _needsPasswordSetup = true;
    notifyListeners();
  }

  Future<void> clear() async {
    _user = null;
    _needsPasswordSetup = false;
    await _storage.clearAll();
    notifyListeners();
  }
}
