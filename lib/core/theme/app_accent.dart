import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selected accent. Replaces [AppColors.highlight] everywhere else stays put.
class AppAccent extends ChangeNotifier {
  AppAccent(this._prefs) {
    final stored = _prefs.getInt(storageKey);
    if (stored != null) {
      _color = Color(stored);
    }
    _bound = this;
  }

  static const storageKey = 'sayge_accent_color';
  static const defaultColor = Color(0xFFFF6B4A);

  static const presets = <AccentChoice>[
    AccentChoice(defaultColor, 'Orange'),
    AccentChoice(Color(0xFFE11D48), 'Rose'),
    AccentChoice(Color(0xFFEA580C), 'Amber'),
    AccentChoice(Color(0xFFCA8A04), 'Gold'),
    AccentChoice(Color(0xFF16A34A), 'Green'),
    AccentChoice(Color(0xFF0F766E), 'Teal'),
    AccentChoice(Color(0xFF2563EB), 'Blue'),
    AccentChoice(Color(0xFF4F46E5), 'Indigo'),
    AccentChoice(Color(0xFF7C3AED), 'Violet'),
    AccentChoice(Color(0xFF111111), 'Black'),
  ];

  static AppAccent? _bound;

  /// Live accent, or the default orange before preferences are loaded.
  static Color get current => _bound?.color ?? defaultColor;

  final SharedPreferences _prefs;
  Color _color = defaultColor;

  Color get color => _color;

  static AppAccent of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccentScope>();
    assert(scope != null, 'AccentScope is missing above this widget');
    return scope!.notifier!;
  }

  Future<void> setColor(Color color) async {
    if (color.toARGB32() == _color.toARGB32()) return;
    _color = color;
    notifyListeners();
    await _prefs.setInt(storageKey, color.toARGB32());
  }
}

class AccentChoice {
  const AccentChoice(this.color, this.name);

  final Color color;
  final String name;
}

class AccentScope extends InheritedNotifier<AppAccent> {
  const AccentScope({
    super.key,
    required AppAccent accent,
    required super.child,
  }) : super(notifier: accent);
}
