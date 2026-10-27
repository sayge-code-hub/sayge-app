import 'package:flutter/foundation.dart';

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
  bool get showBanner =>
      _snapshot.isPastDue ||
      _snapshot.isReadOnly ||
      _snapshot.nearSeatCap ||
      _snapshot.atSeatCap;

  Future<void> refresh() async {
    try {
      final snap = await _remote.fetchSnapshot();
      _snapshot = snap;
      _lastError = null;
    } catch (e) {
      // Schema not applied yet — stay permissive.
      _lastError = e.toString();
      if (!_loaded) {
        _snapshot = BillingSnapshot.permissive;
      }
    }
    _loaded = true;
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
