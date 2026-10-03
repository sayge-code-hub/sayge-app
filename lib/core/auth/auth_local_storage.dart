import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user.dart';

/// Persists the signed-in app user profile across launches.
class AuthLocalStorage {
  AuthLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _userKey = 'sayge_auth_user_v1';

  User? readUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromStorage(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(User user) async {
    final model = user is UserModel
        ? user
        : UserModel(
            id: user.id,
            email: user.email,
            roleId: user.roleId,
            roleCode: user.roleCode,
            roleLabel: user.roleLabel,
            name: user.name,
            employeeId: user.employeeId,
          );
    await _prefs.setString(_userKey, jsonEncode(model.toStorageJson()));
  }

  Future<void> clear() async {
    await _prefs.remove(_userKey);
  }

  /// Wipes all SharedPreferences keys so no login/profile residue remains.
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
