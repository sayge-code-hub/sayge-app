import 'package:flutter/foundation.dart';

/// In-memory unlock for the secret platform ops console (not Supabase auth).
class PlatformOpsSession extends ChangeNotifier {
  bool _unlocked = false;

  bool get isUnlocked => _unlocked;

  void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    notifyListeners();
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }
}
