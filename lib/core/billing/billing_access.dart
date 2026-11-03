import 'package:flutter/foundation.dart';

import '../modules/app_modules.dart';
import 'billing_models.dart';
import 'billing_remote_datasource.dart';

/// Deployment-wide billing gates (closed beta singleton).
///
/// Loaded after login via [refresh]. Fail-open to [BillingSnapshot.permissive]
/// when the billing SQL pack is not applied yet, so older environments keep
/// working.
class BillingAccess extends ChangeNotifier {
  BillingAccess(this._remote);

  final BillingRemoteDataSource _remote;

  BillingSnapshot _snapshot = BillingSnapshot.permissive;
  bool _loaded = false;
  String? _lastError;

  BillingSnapshot get snapshot => _snapshot;
  bool get loaded => _loaded;
  String? get lastError => _lastError;

  bool get writesAllowed => _snapshot.writesAllowed;
  bool get canAddEmployee => _snapshot.canAddEmployee;
  bool get posEnabled => _snapshot.posEnabled;
  bool get modulesSelected => _snapshot.modulesSelected;
  List<String> get enabledModules => _snapshot.enabledModules;
  bool get showBanner =>
      _snapshot.isPastDue ||
      _snapshot.isReadOnly ||
      _snapshot.nearSeatCap ||
      _snapshot.atSeatCap;

  bool hasModule(AppModule module) =>
      _snapshot.enabledModules.contains(module.code);

  bool hasModuleCode(String code) =>
      _snapshot.enabledModules.contains(code.trim().toLowerCase());

  /// First enabled module home, else settings.
  String get firstModuleHome {
    for (final m in AppModule.values) {
      if (!hasModule(m)) continue;
      final path = m.homePath;
      if (path != null) return path;
    }
    return '/settings';
  }

  Future<void> refresh() async {
    try {
      final snap = await _remote.fetchSnapshot();
      _snapshot = snap;
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      if (!_loaded) {
        final msg = e.toString().toLowerCase();
        final missingRpc = msg.contains('could not find the function') ||
            msg.contains('pgrst202') ||
            msg.contains('404');
        // Missing billing pack → legacy all-access. Network/other errors →
        // empty modules (no accidental unlock of every pack on refresh).
        _snapshot = missingRpc
            ? BillingSnapshot.legacyAllModules
            : BillingSnapshot.permissive;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setModules(List<AppModule> modules) async {
    final codes = modules.map((m) => m.code).toList(growable: false);
    final snap = await _remote.setModules(codes);
    _snapshot = snap;
    _loaded = true;
    _lastError = null;
    notifyListeners();
  }

  void applyState(BillingState state) {
    _snapshot = state.snapshot;
    _loaded = true;
    _lastError = null;
    notifyListeners();
  }

  void reset() {
    _snapshot = BillingSnapshot.permissive;
    _loaded = false;
    _lastError = null;
    notifyListeners();
  }
}
