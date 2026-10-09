import 'package:equatable/equatable.dart';

/// Monthly profitability for one employee on a client.
///
/// Model: client billing − employee package = our profit.
class EmployeeProfitability extends Equatable {
  const EmployeeProfitability({
    required this.employeeId,
    required this.employeeName,
    required this.designation,
    required this.clientId,
    required this.clientName,
    required this.billingMonthly,
    required this.packageMonthly,
    required this.grossProfit,
    required this.marginPercent,
    required this.dateOfJoining,
    this.dateOfExit,
  });

  final String employeeId;
  final String employeeName;
  final String designation;
  final String clientId;
  final String clientName;
  final double billingMonthly;
  final double packageMonthly;
  final double grossProfit;
  final double marginPercent;
  final DateTime dateOfJoining;
  final DateTime? dateOfExit;

  bool get hasBillingRate => billingMonthly > 0;

  double get billingAnnual => billingMonthly * 12;
  double get packageAnnual => packageMonthly * 12;

  double get revenue => billingMonthly;
  double get totalCost => packageMonthly;

  bool wasEmployedIn({required int month, required int year}) {
    final period = DateTime(year, month, 1);
    final joined = DateTime(dateOfJoining.year, dateOfJoining.month, 1);
    if (period.isBefore(joined)) return false;
    final exit = dateOfExit;
    if (exit == null) return true;
    final exitMonth = DateTime(exit.year, exit.month, 1);
    return !period.isAfter(exitMonth);
  }

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        designation,
        clientId,
        clientName,
        billingMonthly,
        packageMonthly,
        grossProfit,
        marginPercent,
        dateOfJoining,
        dateOfExit,
      ];
}

/// Rolled-up profitability for one client (or company / misc).
class ClientProfitability extends Equatable {
  const ClientProfitability({
    required this.clientId,
    required this.clientName,
    required this.employeeCount,
    required this.billingMonthly,
    required this.packageMonthly,
    required this.expensesMonthly,
    required this.grossProfit,
    required this.marginPercent,
    required this.employees,
  });

  final String clientId;
  final String clientName;
  final int employeeCount;
  final double billingMonthly;
  final double packageMonthly;

  /// Approved expenses attributed to this client for the current month.
  final double expensesMonthly;
  final double grossProfit;
  final double marginPercent;
  final List<EmployeeProfitability> employees;

  double get revenue => billingMonthly;
  double get totalCost => packageMonthly + expensesMonthly;

  ClientProfitability copyWith({
    String? clientId,
    String? clientName,
    int? employeeCount,
    double? billingMonthly,
    double? packageMonthly,
    double? expensesMonthly,
    double? grossProfit,
    double? marginPercent,
    List<EmployeeProfitability>? employees,
  }) {
    return ClientProfitability(
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      employeeCount: employeeCount ?? this.employeeCount,
      billingMonthly: billingMonthly ?? this.billingMonthly,
      packageMonthly: packageMonthly ?? this.packageMonthly,
      expensesMonthly: expensesMonthly ?? this.expensesMonthly,
      grossProfit: grossProfit ?? this.grossProfit,
      marginPercent: marginPercent ?? this.marginPercent,
      employees: employees ?? this.employees,
    );
  }

  @override
  List<Object?> get props => [
        clientId,
        clientName,
        employeeCount,
        billingMonthly,
        packageMonthly,
        expensesMonthly,
        grossProfit,
        marginPercent,
        employees,
      ];
}

/// One month of rolled-up client profitability.
class MonthlyProfitability extends Equatable {
  const MonthlyProfitability({
    required this.year,
    required this.month,
    required this.billing,
    required this.packageAmount,
    required this.expenses,
    required this.profit,
    required this.marginPercent,
    required this.employeeCount,
  });

  final int year;
  final int month;
  final double billing;
  final double packageAmount;
  final double expenses;
  final double profit;
  final double marginPercent;
  final int employeeCount;

  @override
  List<Object?> get props => [
        year,
        month,
        billing,
        packageAmount,
        expenses,
        profit,
        marginPercent,
        employeeCount,
      ];
}
