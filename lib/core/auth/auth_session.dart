import 'package:flutter/foundation.dart';

import '../../features/auth/domain/entities/user.dart';

/// Holds the signed-in user so go_router can redirect and shells can read it.
class AuthSession extends ChangeNotifier {
  User? _user;

  User? get user => _user;

  bool get isAuthenticated => _user != null;

  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
