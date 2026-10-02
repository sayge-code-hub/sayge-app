import 'package:equatable/equatable.dart';

class PayslipLine extends Equatable {
  const PayslipLine({required this.description, required this.amount});

  final String description;
  final double amount;

  @override
  List<Object?> get props => [description, amount];
}

class Payslip extends Equatable {
  const Payslip({
    required this.month,
    required this.year,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.grade,
    required this.dateOfJoining,
    required this.designation,
    required this.location,
    required this.ifsc,
    required this.bankAccount,
    required this.pan,
    required this.uan,
    required this.payableDays,
    required this.lopDays,
    required this.earnings,
    required this.deductions,
    required this.grossEarnings,
    required this.totalDeductions,
    required this.netPay,
    required this.netPayInWords,
  });

  final int month;
  final int year;
  final String employeeId;
  final String employeeName;
  final String department;
  final String grade;
  final DateTime dateOfJoining;
  final String designation;
  final String location;
  final String ifsc;
  final String bankAccount;
  final String pan;
  final String uan;
  final int payableDays;
  final int lopDays;
  final List<PayslipLine> earnings;
  final List<PayslipLine> deductions;
  final double grossEarnings;
  final double totalDeductions;
  final double netPay;
  final String netPayInWords;

  String get periodLabel {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[month - 1]}-$year';
  }

  @override
  List<Object?> get props => [
        month,
        year,
        employeeId,
        employeeName,
        netPay,
      ];
}
