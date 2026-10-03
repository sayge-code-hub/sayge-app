import '../../../../core/config/app_payroll_config.dart';
import '../../../../core/utils/indian_number_to_words.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../entities/payslip.dart';

abstract final class PayslipCalculator {
  /// Full-month gross + basic derived from Monthly CTC.
  ///
  /// When PF applies:
  /// `Monthly CTC = Gross + Employer PF + Retention`
  /// `Basic = 2/3 × Gross`, `Employer PF = 12% × Basic`
  /// ⇒ `Monthly CTC − Retention = Basic × (3/2 + 0.12)`
  static ({double gross, double basic}) fullMonthEarnings(Employee employee) {
    final retention = AppPayrollConfig.monthlyCtcIncludesRetention
        ? employee.retentionAmount
        : 0.0;
    final remaining =
        (employee.monthlyCtc - retention).clamp(0.0, double.infinity).toDouble();

    if (employee.pfApplicable &&
        AppPayrollConfig.monthlyCtcIncludesEmployerPf) {
      // remaining = basic/share + basic*pfRate = basic * (1/share + pfRate)
      final basicFactor =
          (1 / AppPayrollConfig.basicShareOfGross) +
              AppPayrollConfig.pfRateOnBasic;
      final basic = _round(remaining / basicFactor);
      final employerPf = _round(basic * AppPayrollConfig.pfRateOnBasic);
      final gross = _round(remaining - employerPf);
      return (gross: gross, basic: basic);
    }

    final gross = _round(remaining);
    final basic = _round(gross * AppPayrollConfig.basicShareOfGross);
    return (gross: gross, basic: basic);
  }

  static Payslip fromEmployee({
    required Employee employee,
    required int month,
    required int year,
    int lopDays = 0,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final payableDays = (daysInMonth - lopDays).clamp(0, daysInMonth);
    final dayFactor = daysInMonth == 0 ? 1.0 : payableDays / daysInMonth;

    final full = fullMonthEarnings(employee);
    final gross = _round(full.gross * dayFactor);
    final specialCap = _round(employee.specialAllowance * dayFactor);

    late final double basic;
    late final double hra;
    late final double special;
    if (specialCap > 0) {
      // Carve fixed special first, then split the rest Basic 2/3 : HRA 1/3.
      final pool = (gross - specialCap).clamp(0.0, gross).toDouble();
      basic = _round(pool * AppPayrollConfig.basicShareOfGross);
      hra = _round(basic * AppPayrollConfig.hraShareOfBasic);
      special = _round(gross - basic - hra);
    } else {
      basic = _round(full.basic * dayFactor);
      hra = _round(basic * AppPayrollConfig.hraShareOfBasic);
      final residual = _round(gross - basic - hra);
      special = residual < 0 ? 0.0 : residual;
    }

    final earnings = <PayslipLine>[
      PayslipLine(description: 'Basic', amount: basic),
      PayslipLine(description: 'HRA', amount: hra),
      PayslipLine(description: 'Special Allowance', amount: special),
    ];

    final pf = employee.pfApplicable
        ? _round(basic * AppPayrollConfig.pfRateOnBasic)
        : 0.0;
    final pt = employee.ptApplicable
        ? AppPayrollConfig.professionalTaxAmount
        : 0.0;
    final medical = _round(employee.medicalInsurance * dayFactor);
    final tds = _round(employee.tdsAmount * dayFactor);
    final retirals = _round(employee.retentionAmount * dayFactor);

    final deductions = <PayslipLine>[
      if (pf > 0) PayslipLine(description: 'Provident Fund', amount: pf),
      if (pt > 0) PayslipLine(description: 'Professional Tax', amount: pt),
      PayslipLine(description: 'Medical Insurance', amount: medical),
      PayslipLine(description: 'Income Tax (TDS)', amount: tds),
      PayslipLine(description: 'Retirals', amount: retirals),
    ];

    final totalDeductions = _round(
      deductions.fold<double>(0, (sum, line) => sum + line.amount),
    );
    final net = _round(gross - totalDeductions);

    return Payslip(
      month: month,
      year: year,
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      department: employee.department,
      grade: employee.grade,
      dateOfJoining: employee.dateOfJoining,
      designation: employee.designation,
      location: employee.location,
      ifsc: employee.ifsc,
      bankAccount: employee.bankAccount,
      pan: employee.pan,
      uan: employee.uan,
      payableDays: payableDays,
      lopDays: lopDays,
      earnings: earnings,
      deductions: deductions,
      grossEarnings: gross,
      totalDeductions: totalDeductions,
      netPay: net < 0 ? 0 : net,
      netPayInWords: IndianNumberToWords.convert(net < 0 ? 0 : net),
    );
  }

  static double _round(double value) => value.roundToDouble();
}
