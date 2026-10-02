import 'package:intl/intl.dart';

import '../config/app_display_config.dart';

/// Formats amounts using [AppDisplayConfig] (INR / ₹ by default).
abstract final class MoneyFormat {
  static final NumberFormat _number = NumberFormat.decimalPattern(
    AppDisplayConfig.locale,
  )..minimumFractionDigits = AppDisplayConfig.moneyDecimalDigits
    ..maximumFractionDigits = AppDisplayConfig.moneyDecimalDigits;

  /// e.g. `₹ 6,75,000`
  static String format(num value) {
    final amount = AppDisplayConfig.moneyDecimalDigits == 0
        ? value.round()
        : value;
    return '${AppDisplayConfig.currencySymbol}'
        '${AppDisplayConfig.currencySymbolSpacer}'
        '${_number.format(amount)}';
  }

  /// Amount only (no symbol) — prefer [format] for UI.
  static String formatAmount(num value) {
    final amount = AppDisplayConfig.moneyDecimalDigits == 0
        ? value.round()
        : value;
    return _number.format(amount);
  }
}

/// Formats dates using [AppDisplayConfig] patterns.
abstract final class AppDates {
  static final DateFormat compact = DateFormat(AppDisplayConfig.datePattern);
  static final DateFormat medium = DateFormat(
    AppDisplayConfig.datePatternMedium,
  );
  static final DateFormat short = DateFormat(AppDisplayConfig.datePatternShort);
  static final DateFormat dms = DateFormat(AppDisplayConfig.datePatternDms);
}
