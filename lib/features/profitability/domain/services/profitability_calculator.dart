import '../../../expenses/domain/entities/expense.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../payroll/domain/services/payslip_period.dart';
import '../entities/profitability.dart';

/// Profitability from placement margin:
/// billing − package − approved expenses = profit.
abstract final class ProfitabilityCalculator {
  static EmployeeProfitability forEmployee(Employee employee) {
    final billing = _round(employee.monthlyRate);
    final package = _packageMonthly(employee);
    final grossProfit = _round(billing - package);
    final marginPercent =
        billing > 0 ? _round((grossProfit / billing) * 1000) / 10 : 0.0;

    return EmployeeProfitability(
      employeeId: employee.employeeId,
      employeeName: employee.employeeName,
      designation: employee.designation,
      clientId: employee.clientId,
      clientName:
          employee.client.trim().isEmpty ? 'Unassigned' : employee.client,
      billingMonthly: billing,
      packageMonthly: package,
      grossProfit: grossProfit,
      marginPercent: marginPercent,
      dateOfJoining: employee.dateOfJoining,
      dateOfExit: employee.dateOfExit,
    );
  }

  static List<EmployeeProfitability> forEmployees(
    Iterable<Employee> employees,
  ) {
    return [
      for (final employee in employees)
        if (_include(employee)) forEmployee(employee),
    ]..sort((a, b) {
        final byClient = a.clientName.toLowerCase().compareTo(
              b.clientName.toLowerCase(),
            );
        if (byClient != 0) return byClient;
        return a.employeeName.toLowerCase().compareTo(
              b.employeeName.toLowerCase(),
            );
      });
  }

  static List<ClientProfitability> rollUpByClient(
    List<EmployeeProfitability> rows, {
    List<Expense> expenses = const [],
    DateTime? now,
  }) {
    // One company is one entity even when billing salutations are separate rows.
    final byClient = <String, List<EmployeeProfitability>>{};
    for (final row in rows) {
      final name = row.clientName.trim().toLowerCase();
      final key = name.isEmpty
          ? (row.clientId.trim().isEmpty ? '__unassigned__' : row.clientId.trim())
          : name;
      (byClient[key] ??= []).add(row);
    }

    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);
    final current = now ?? DateTime.now();

    final clients = <ClientProfitability>[];
    for (final entry in byClient.entries) {
      final list = entry.value;
      final billing =
          _round(list.fold<double>(0, (s, e) => s + e.billingMonthly));
      final package =
          _round(list.fold<double>(0, (s, e) => s + e.packageMonthly));
      final clientId = _representativeClientId(list);
      final monthExpenses = _expensesInMonth(
        approved,
        clientKey: clientId,
        clientName: list.first.clientName,
        year: current.year,
        month: current.month,
      );
      final grossProfit = _round(billing - package - monthExpenses);
      final marginPercent =
          billing > 0 ? _round((grossProfit / billing) * 1000) / 10 : 0.0;
      clients.add(
        ClientProfitability(
          clientId: clientId,
          clientName: list.first.clientName,
          employeeCount: list.length,
          billingMonthly: billing,
          packageMonthly: package,
          expensesMonthly: monthExpenses,
          grossProfit: grossProfit,
          marginPercent: marginPercent,
          employees: list,
        ),
      );
    }

    final companyExpenses = _expensesInMonth(
      approved,
      clientKey: Expense.companyScopeId,
      year: current.year,
      month: current.month,
    );
    if (companyExpenses > 0 || approved.any((e) => e.isCompanyExpense)) {
      clients.add(
        ClientProfitability(
          clientId: Expense.companyScopeId,
          clientName: Expense.companyScopeLabel,
          employeeCount: 0,
          billingMonthly: 0,
          packageMonthly: 0,
          expensesMonthly: companyExpenses,
          grossProfit: _round(-companyExpenses),
          marginPercent: 0,
          employees: const [],
        ),
      );
    }

    // Ensure clients that only have expenses (no employees) still appear.
    final seenNames = clients
        .map((c) => c.clientName.trim().toLowerCase())
        .toSet();
    final seenIds = clients.map((c) => c.clientId).toSet();
    final orphanKeys = <String, String>{};
    for (final expense in approved) {
      if (expense.isCompanyExpense) continue;
      final name = expense.clientName?.trim() ?? '';
      final nameKey = name.toLowerCase();
      if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;
      final key = expense.profitabilityClientKey;
      if (seenIds.contains(key)) continue;
      orphanKeys[key] = name.isNotEmpty ? name : 'Client';
    }
    for (final entry in orphanKeys.entries) {
      final monthExpenses = _expensesInMonth(
        approved,
        clientKey: entry.key,
        year: current.year,
        month: current.month,
      );
      clients.add(
        ClientProfitability(
          clientId: entry.key,
          clientName: entry.value,
          employeeCount: 0,
          billingMonthly: 0,
          packageMonthly: 0,
          expensesMonthly: monthExpenses,
          grossProfit: _round(-monthExpenses),
          marginPercent: 0,
          employees: const [],
        ),
      );
    }

    clients.sort((a, b) {
      if (a.clientId == Expense.companyScopeId) return 1;
      if (b.clientId == Expense.companyScopeId) return -1;
      return b.billingMonthly.compareTo(a.billingMonthly);
    });
    return clients;
  }

  /// Month-wise rollup for a client using current billing/package rates.
  static List<MonthlyProfitability> monthWiseForClient(
    ClientProfitability client, {
    List<Expense> expenses = const [],
    DateTime? now,
  }) {
    final months = PayslipPeriod.optionsForAdmin(now);
    if (months.isEmpty) return const [];
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);

    return [
      for (final period in months.reversed)
        _monthRow(
          client,
          period.year,
          period.month,
          expenses: approved,
        ),
    ];
  }

  /// Indian FY months (Apr → Mar) for [fyStartYear] (e.g. 2026 → FY 2026-27).
  static List<MonthlyProfitability> financialYearProjection(
    ClientProfitability client, {
    required int fyStartYear,
    List<Expense> expenses = const [],
  }) {
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);
    return [
      for (var i = 0; i < 12; i++)
        _monthRow(
          client,
          i < 9 ? fyStartYear : fyStartYear + 1,
          i < 9 ? i + 4 : i - 8,
          expenses: approved,
        ),
    ];
  }

  /// FY start years available for the dropdown (current FY ± 1).
  static List<int> financialYearOptions([DateTime? now]) {
    final current = now ?? DateTime.now();
    final currentFyStart =
        current.month >= 4 ? current.year : current.year - 1;
    return [
      for (var y = currentFyStart - 1; y <= currentFyStart + 1; y++) y,
    ];
  }

  static String financialYearLabel(int fyStartYear) =>
      'FY $fyStartYear-${(fyStartYear + 1) % 100}';

  static MonthlyProfitability _monthRow(
    ClientProfitability client,
    int year,
    int month, {
    List<Expense> expenses = const [],
  }) {
    final active = client.employees
        .where((e) => e.wasEmployedIn(month: month, year: year))
        .toList(growable: false);
    final billing =
        _round(active.fold<double>(0, (s, e) => s + e.billingMonthly));
    final package =
        _round(active.fold<double>(0, (s, e) => s + e.packageMonthly));
    final monthExpenses = _expensesInMonth(
      expenses,
      clientKey: client.clientId,
      clientName: client.clientName,
      year: year,
      month: month,
    );
    final profit = _round(billing - package - monthExpenses);
    final margin =
        billing > 0 ? _round((profit / billing) * 1000) / 10 : 0.0;
    return MonthlyProfitability(
      year: year,
      month: month,
      billing: billing,
      packageAmount: package,
      expenses: monthExpenses,
      profit: profit,
      marginPercent: margin,
      employeeCount: active.length,
    );
  }

  static String _representativeClientId(List<EmployeeProfitability> list) {
    final counts = <String, int>{};
    for (final row in list) {
      final id = row.clientId.trim();
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    var best = list.first.clientId;
    var bestCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > bestCount) {
        best = entry.key;
        bestCount = entry.value;
      }
    }
    return best;
  }

  static double _expensesInMonth(
    List<Expense> expenses, {
    required String clientKey,
    String? clientName,
    required int year,
    required int month,
  }) {
    final company = (clientName ?? '').trim().toLowerCase();
    var total = 0.0;
    for (final expense in expenses) {
      if (clientKey == Expense.companyScopeId) {
        if (!expense.isCompanyExpense) continue;
      } else if (expense.isCompanyExpense) {
        continue;
      } else {
        final byName = company.isNotEmpty &&
            (expense.clientName ?? '').trim().toLowerCase() == company;
        final byId = (expense.clientId ?? '').trim() == clientKey;
        if (!byName && !byId) continue;
      }
      final at = expense.createdAt?.toLocal();
      if (at == null) continue;
      if (at.year != year || at.month != month) continue;
      total += expense.amount;
    }
    return _round(total);
  }

  static double _packageMonthly(Employee employee) {
    if (employee.annualCtc > 0) {
      return _round(employee.annualCtc / 12);
    }
    return _round(employee.monthlyCtc);
  }

  static bool _include(Employee employee) {
    if (employee.isDraft) return false;
    if (!employee.isActive) return false;
    return employee.clientId.trim().isNotEmpty ||
        employee.client.trim().isNotEmpty;
  }

  static double _round(double value) => value.roundToDouble();
}
