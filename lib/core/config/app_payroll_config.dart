/// Payroll / payslip calculation knobs.
/// Change here to adjust slip structure company-wide.
abstract final class AppPayrollConfig {
  /// Basic as a fraction of **gross earnings** (sample slip uses 2/3).
  static const double basicShareOfGross = 2 / 3;

  /// HRA as a fraction of basic (sample slip uses 1/2).
  static const double hraShareOfBasic = 0.5;

  /// Employee PF rate on basic when PF is applicable.
  /// Employer PF uses the same rate on basic and is part of Monthly CTC
  /// (not part of Gross Earnings).
  static const double pfRateOnBasic = 0.12;

  /// Fixed professional tax (INR) when PT is applicable.
  static const double professionalTaxAmount = 200;

  /// Monthly CTC composition when PF is applicable:
  /// `Monthly CTC = Gross Earnings + Employer PF + Retention`
  /// where `Employer PF = pfRateOnBasic × Basic` and
  /// `Basic = basicShareOfGross × Gross`.
  /// Therefore:
  /// `Gross = (Monthly CTC − Retention) / (1 + pfRateOnBasic × basicShareOfGross)`
  static const bool monthlyCtcIncludesEmployerPf = true;

  /// Whether retention is treated as an employer CTC component (above gross).
  static const bool monthlyCtcIncludesRetention = true;

  static const String disclaimer =
      'Disclaimer : This is a system generated payslip, does not require any signature.';

  static const String amountsNote = 'All amounts are in INR';
}
