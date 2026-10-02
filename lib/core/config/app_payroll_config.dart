/// Payroll / payslip calculation knobs.
/// Change here to adjust slip structure company-wide.
abstract final class AppPayrollConfig {
  /// Basic as a fraction of gross earnings (sample slip uses 2/3).
  static const double basicShareOfGross = 2 / 3;

  /// HRA as a fraction of basic (sample slip uses 1/2).
  static const double hraShareOfBasic = 0.5;

  /// Employee PF rate on basic when PF is applicable.
  static const double pfRateOnBasic = 0.12;

  /// Fixed professional tax (INR) when PT is applicable.
  static const double professionalTaxAmount = 200;

  /// Income tax (TDS) — set when tax engine exists; 0 for now.
  static const double defaultTdsAmount = 0;

  /// Treat [Employee.monthlyCtc] as gross earnings for the slip.
  static const bool monthlyCtcIsGross = true;

  static const String disclaimer =
      'Disclaimer : This is a system generated payslip, does not require any signature.';

  static const String amountsNote = 'All amounts are in INR';
}
