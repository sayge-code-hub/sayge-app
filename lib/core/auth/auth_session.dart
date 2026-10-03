import 'package:flutter/foundation.dart';

import '../../features/auth/domain/entities/user.dart';
import 'auth_local_storage.dart';

/// Holds the signed-in user so go_router can redirect and shells can read it.
///
/// Profile is persisted via [AuthLocalStorage] (SharedPreferences).
class AuthSession extends ChangeNotifier {
  AuthSession({
    required this._storage,
    User? initialUser,
  }) : _user = initialUser;

  final AuthLocalStorage _storage;
  User? _user;

  User? get user => _user;

  bool get isAuthenticated => _user != null;

  Future<void> setUser(User user) async {
    _user = user;
    await _storage.saveUser(user);
    notifyListeners();
  }

  Future<void> clear() async {
    _user = null;
    await _storage.clearAll();
    notifyListeners();
  }
}
