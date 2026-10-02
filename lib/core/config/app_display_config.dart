/// App-wide display settings (currency, locale, date patterns).
///
/// Change values here to update formatting everywhere in the UI.
abstract final class AppDisplayConfig {
  /// ISO currency code (e.g. INR, USD).
  static const String currencyCode = 'INR';

  /// Symbol shown next to amounts (e.g. ₹).
  static const String currencySymbol = '₹';

  /// Locale used for Indian grouping (e.g. 6,75,000).
  static const String locale = 'en_IN';

  /// Fraction digits for money display (0 = whole rupees).
  static const int moneyDecimalDigits = 0;

  /// Space between symbol and amount: "₹ 6,75,000".
  static const String currencySymbolSpacer = ' ';

  /// Compact form dates (forms, detail fields).
  static const String datePattern = 'dd-MM-yyyy';

  /// Medium list dates (employee table).
  static const String datePatternMedium = 'MMMM d, yyyy';

  /// Short card dates.
  static const String datePatternShort = 'MMM d, yyyy';

  /// Document / DMS dates.
  static const String datePatternDms = 'dd MMM yyyy';
}
