import '../../../../core/config/app_payroll_config.dart';
import '../../../../core/utils/indian_number_to_words.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../entities/payslip.dart';

abstract final class PayslipCalculator {
  static Payslip fromEmployee({
    required Employee employee,
    required int month,
    required int year,
    int lopDays = 0,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final payableDays = (daysInMonth - lopDays).clamp(0, daysInMonth);

    final fullGross = AppPayrollConfig.monthlyCtcIsGross
        ? employee.monthlyCtc
        : employee.monthlyCtc;
    final dayFactor = daysInMonth == 0 ? 1.0 : payableDays / daysInMonth;
    final gross = _round(fullGross * dayFactor);

    final basic = _round(gross * AppPayrollConfig.basicShareOfGross);
    final hra = _round(basic * AppPayrollConfig.hraShareOfBasic);
    var special = _round(gross - basic - hra);
    if (special < 0) special = 0;

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
    final medical = employee.medicalInsurance;
    final tds = AppPayrollConfig.defaultTdsAmount;
    final retirals = employee.retentionAmount;

    final deductions = <PayslipLine>[
      PayslipLine(description: 'Provident Fund', amount: pf),
      PayslipLine(description: 'Professional Tax', amount: pt),
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
