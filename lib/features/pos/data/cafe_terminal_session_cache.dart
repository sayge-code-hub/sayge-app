import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/cafe_entities.dart';

/// One in-progress terminal tab (per table or takeaway) until the bill settles.
class CafeTerminalSession {
  CafeTerminalSession({
    required this.orderType,
    this.tableNo = '',
    List<CafeCartLine>? lines,
    this.couponId,
    this.couponCode = '',
  }) : lines = lines ?? [];

  CafeOrderType orderType;
  String tableNo;
  final List<CafeCartLine> lines;
  String? couponId;
  String couponCode;

  static String keyFor({
    required CafeOrderType orderType,
    String tableNo = '',
  }) {
    if (orderType == CafeOrderType.takeaway) return 'takeaway';
    final t = tableNo.trim();
    return t.isEmpty ? 'dine' : 'dine:$t';
  }

  String get storageKey =>
      keyFor(orderType: orderType, tableNo: tableNo);

  String get label {
    if (orderType == CafeOrderType.takeaway) return 'Takeaway';
    final t = tableNo.trim();
    return t.isEmpty ? 'Dine-in' : 'Table $t';
  }

  int get itemCount =>
      lines.fold<int>(0, (s, l) => s + l.quantity.round());

  bool get isEmpty => lines.isEmpty;

  CafeTerminalSession copyEmpty() => CafeTerminalSession(
        orderType: orderType,
        tableNo: tableNo,
      );

  Map<String, dynamic> toJson() => {
        'orderType': orderType.dbValue,
        'tableNo': tableNo,
        'couponId': couponId,
        'couponCode': couponCode,
        'lines': [
          for (final l in lines)
            {
              'menuItemId': l.menuItem.id,
              'quantity': l.quantity,
              'notes': l.notes,
            },
        ],
      };

  static CafeTerminalSession fromJson(
    Map<String, dynamic> json, {
    required Map<String, CafeMenuItem> menuById,
  }) {
    final type = CafeOrderTypeX.fromDb(json['orderType']?.toString());
    final tableNo = (json['tableNo'] ?? '').toString().trim();
    final couponIdRaw = (json['couponId'] ?? '').toString().trim();
    final couponCode = (json['couponCode'] ?? '').toString();
    final rawLines = json['lines'];
    final lines = <CafeCartLine>[];
    if (rawLines is List) {
      for (final row in rawLines) {
        if (row is! Map) continue;
        final id = (row['menuItemId'] ?? '').toString();
        final item = menuById[id];
        if (item == null) continue;
        final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
        if (qty <= 0) continue;
        lines.add(
          CafeCartLine(
            menuItem: item,
            quantity: qty,
            notes: (row['notes'] ?? '').toString(),
          ),
        );
      }
    }
    return CafeTerminalSession(
      orderType: type,
      tableNo: tableNo,
      lines: lines,
      couponId: couponIdRaw.isEmpty ? null : couponIdRaw,
      couponCode: couponCode,
    );
  }
}

/// Persists open terminal tabs locally so waiters can leave and resume.
class CafeTerminalSessionCache {
  CafeTerminalSessionCache(this._prefs);

  final SharedPreferences _prefs;

  String _key(String cafeId) => 'cafe_pos_open_tabs_$cafeId';

  Future<({Map<String, CafeTerminalSession> sessions, String? activeKey})>
      load({
    required String cafeId,
    required List<CafeMenuItem> menu,
  }) async {
    final raw = _prefs.getString(_key(cafeId));
    if (raw == null || raw.isEmpty) {
      return (sessions: <String, CafeTerminalSession>{}, activeKey: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return (sessions: <String, CafeTerminalSession>{}, activeKey: null);
      }
      final menuById = {for (final m in menu) m.id: m};
      final sessions = <String, CafeTerminalSession>{};
      final list = decoded['sessions'];
      if (list is List) {
        for (final row in list) {
          if (row is! Map) continue;
          final session = CafeTerminalSession.fromJson(
            Map<String, dynamic>.from(row),
            menuById: menuById,
          );
          // Keep empty sessions only if they have a table assigned (open tab).
          if (session.isEmpty &&
              (session.orderType == CafeOrderType.takeaway ||
                  session.tableNo.trim().isEmpty)) {
            continue;
          }
          sessions[session.storageKey] = session;
        }
      }
      final active = decoded['activeKey']?.toString();
      return (
        sessions: sessions,
        activeKey: active != null && sessions.containsKey(active)
            ? active
            : (sessions.isEmpty ? null : sessions.keys.first),
      );
    } catch (_) {
      return (sessions: <String, CafeTerminalSession>{}, activeKey: null);
    }
  }

  Future<void> save({
    required String cafeId,
    required Map<String, CafeTerminalSession> sessions,
    required String? activeKey,
  }) async {
    final payload = {
      'activeKey': activeKey,
      'sessions': [
        for (final s in sessions.values)
          if (!s.isEmpty ||
              (s.orderType == CafeOrderType.dineIn &&
                  s.tableNo.trim().isNotEmpty))
            s.toJson(),
      ],
    };
    await _prefs.setString(_key(cafeId), jsonEncode(payload));
  }

  Future<void> clear(String cafeId) async {
    await _prefs.remove(_key(cafeId));
  }
}
