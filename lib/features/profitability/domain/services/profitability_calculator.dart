import '../../../expenses/domain/entities/expense.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../payroll/domain/services/payslip_period.dart';
import '../entities/profitability.dart';

/// Profitability from placement margin:
/// invoiced billing − package − approved expenses = profit.
///
/// Client billing uses tax invoices (`taxableAmount`) matched by buyer company
/// name. Employee `monthlyRate` remains the contracted rate on employee rows
/// and is used only to forecast months that are still in the future.
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
    List<Invoice> invoices = const [],
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
      final activeNow = list
          .where(
            (e) => e.wasEmployedIn(
              month: current.month,
              year: current.year,
            ),
          )
          .toList(growable: false);
      final package =
          _round(activeNow.fold<double>(0, (s, e) => s + e.packageMonthly));
      final clientId = _representativeClientId(list);
      final clientName = list.first.clientName;
      final billing = _invoicesInMonth(
        invoices,
        clientName: clientName,
        year: current.year,
        month: current.month,
      );
      final monthExpenses = _expensesInMonth(
        approved,
        clientKey: clientId,
        clientName: clientName,
        year: current.year,
        month: current.month,
      );
      final grossProfit = _round(billing - package - monthExpenses);
      final marginPercent =
          billing > 0 ? _round((grossProfit / billing) * 1000) / 10 : 0.0;
      clients.add(
        ClientProfitability(
          clientId: clientId,
          clientName: clientName,
          employeeCount: activeNow.length,
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

    // Clients that only have expenses (no employees) still appear.
    final seenNames = clients
        .map((c) => c.clientName.trim().toLowerCase())
        .toSet();
    final seenIds = clients.map((c) => c.clientId).toSet();
    final orphanExpenseKeys = <String, String>{};
    for (final expense in approved) {
      if (expense.isCompanyExpense) continue;
      final name = expense.clientName?.trim() ?? '';
      final nameKey = name.toLowerCase();
      if (nameKey.isNotEmpty && seenNames.contains(nameKey)) continue;
      final key = expense.profitabilityClientKey;
      if (seenIds.contains(key)) continue;
      orphanExpenseKeys[key] = name.isNotEmpty ? name : 'Client';
    }
    for (final entry in orphanExpenseKeys.entries) {
      final name = entry.value;
      final billing = _invoicesInMonth(
        invoices,
        clientName: name,
        year: current.year,
        month: current.month,
      );
      final monthExpenses = _expensesInMonth(
        approved,
        clientKey: entry.key,
        clientName: name,
        year: current.year,
        month: current.month,
      );
      clients.add(
        ClientProfitability(
          clientId: entry.key,
          clientName: name,
          employeeCount: 0,
          billingMonthly: billing,
          packageMonthly: 0,
          expensesMonthly: monthExpenses,
          grossProfit: _round(billing - monthExpenses),
          marginPercent:
              billing > 0 ? _round(((billing - monthExpenses) / billing) * 1000) / 10 : 0,
          employees: const [],
        ),
      );
      seenNames.add(name.trim().toLowerCase());
    }

    // Clients that only have invoices (no employees / expenses) still appear.
    final orphanInvoiceNames = <String>{};
    for (final invoice in invoices) {
      final name = invoice.buyerCompany.trim();
      if (name.isEmpty) continue;
      final nameKey = name.toLowerCase();
      if (seenNames.contains(nameKey)) continue;
      orphanInvoiceNames.add(name);
    }
    for (final name in orphanInvoiceNames) {
      final billing = _invoicesInMonth(
        invoices,
        clientName: name,
        year: current.year,
        month: current.month,
      );
      clients.add(
        ClientProfitability(
          clientId: name.toLowerCase(),
          clientName: name,
          employeeCount: 0,
          billingMonthly: billing,
          packageMonthly: 0,
          expensesMonthly: 0,
          grossProfit: billing,
          marginPercent: billing > 0 ? 100 : 0,
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

  /// Month-wise rollup for a client using invoiced billing.
  ///
  /// Includes the current calendar month (unlike payroll, which waits for
  /// month-end) so in-progress invoices count toward FY totals.
  static List<MonthlyProfitability> monthWiseForClient(
    ClientProfitability client, {
    List<Expense> expenses = const [],
    List<Invoice> invoices = const [],
    DateTime? now,
    int? fyStartYear,
  }) {
    final current = now ?? DateTime.now();
    final months = _monthsThroughCurrent(current);
    if (months.isEmpty) return const [];
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);

    final rows = [
      for (final period in months.reversed)
        _monthRow(
          client,
          period.year,
          period.month,
          expenses: approved,
          invoices: invoices,
          now: current,
          forecastMissingInvoices: false,
        ),
    ];
    if (fyStartYear == null) return rows;
    return rows
        .where((m) => _inFinancialYear(m.year, m.month, fyStartYear))
        .toList(growable: false);
  }

  static List<DateTime> _monthsThroughCurrent(DateTime now) {
    final start = PayslipPeriod.earliestAllowed;
    final end = DateTime(now.year, now.month, 1);
    if (start.isAfter(end)) return const [];
    final options = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      options.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return options;
  }

  /// Indian FY months (Apr → Mar) for [fyStartYear] (e.g. 2026 → FY 2026-27).
  ///
  /// Past and current months use invoices; future months forecast from
  /// contracted employee billing rates.
  static List<MonthlyProfitability> financialYearProjection(
    ClientProfitability client, {
    required int fyStartYear,
    List<Expense> expenses = const [],
    List<Invoice> invoices = const [],
    DateTime? now,
  }) {
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);
    final current = now ?? DateTime.now();
    return [
      for (var i = 0; i < 12; i++)
        _monthRow(
          client,
          i < 9 ? fyStartYear : fyStartYear + 1,
          i < 9 ? i + 4 : i - 8,
          expenses: approved,
          invoices: invoices,
          now: current,
          forecastMissingInvoices: true,
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

  static int currentFinancialYearStart([DateTime? now]) {
    final current = now ?? DateTime.now();
    return current.month >= 4 ? current.year : current.year - 1;
  }

  static bool _inFinancialYear(int year, int month, int fyStartYear) {
    if (month >= 4) return year == fyStartYear;
    return year == fyStartYear + 1;
  }

  /// CSV export of client profitability for [fyStartYear].
  static String exportCsv(
    List<ClientProfitability> clients, {
    required int fyStartYear,
    List<Expense> expenses = const [],
    List<Invoice> invoices = const [],
    DateTime? now,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'Client,Employees,Invoiced,Package,Expenses,Profit,Margin %',
      );
    for (final client in clients) {
      final months = financialYearProjection(
        client,
        fyStartYear: fyStartYear,
        expenses: expenses,
        invoices: invoices,
        now: now,
      );
      // Export actuals only: zero out forecast months (future with no invoices).
      final current = now ?? DateTime.now();
      var invoiced = 0.0;
      var package = 0.0;
      var exp = 0.0;
      for (final m in months) {
        final isFuture = DateTime(m.year, m.month)
            .isAfter(DateTime(current.year, current.month));
        if (isFuture) continue;
        invoiced += m.billing;
        package += m.packageAmount;
        exp += m.expenses;
      }
      invoiced = _round(invoiced);
      package = _round(package);
      exp = _round(exp);
      final profit = _round(invoiced - package - exp);
      final margin =
          invoiced > 0 ? _round((profit / invoiced) * 1000) / 10 : 0.0;
      buffer.writeln(
        [
          _csv(client.clientName),
          client.employeeCount,
          invoiced.toStringAsFixed(2),
          package.toStringAsFixed(2),
          exp.toStringAsFixed(2),
          profit.toStringAsFixed(2),
          margin.toStringAsFixed(1),
        ].join(','),
      );
    }
    return buffer.toString();
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static MonthlyProfitability _monthRow(
    ClientProfitability client,
    int year,
    int month, {
    List<Expense> expenses = const [],
    List<Invoice> invoices = const [],
    DateTime? now,
    bool forecastMissingInvoices = false,
  }) {
    final active = client.employees
        .where((e) => e.wasEmployedIn(month: month, year: year))
        .toList(growable: false);
    final rateBilling =
        _round(active.fold<double>(0, (s, e) => s + e.billingMonthly));
    final package =
        _round(active.fold<double>(0, (s, e) => s + e.packageMonthly));
    final invoiced = _invoicesInMonth(
      invoices,
      clientName: client.clientName,
      year: year,
      month: month,
    );
    final current = now ?? DateTime.now();
    final period = DateTime(year, month);
    final currentMonth = DateTime(current.year, current.month);
    final isFuture = period.isAfter(currentMonth);

    final double billing;
    if (invoiced > 0) {
      billing = invoiced;
    } else if (forecastMissingInvoices && isFuture) {
      billing = rateBilling;
    } else {
      billing = 0;
    }

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

  static double _invoicesInMonth(
    List<Invoice> invoices, {
    required String clientName,
    required int year,
    required int month,
  }) {
    final company = clientName.trim().toLowerCase();
    if (company.isEmpty ||
        company == Expense.companyScopeLabel.toLowerCase()) {
      return 0;
    }
    var total = 0.0;
    for (final invoice in invoices) {
      final buyer = invoice.buyerCompany.trim().toLowerCase();
      if (buyer.isEmpty || buyer != company) continue;
      final date = invoice.invoiceDate;
      if (date.year != year || date.month != month) continue;
      final amount =
          invoice.taxableAmount > 0 ? invoice.taxableAmount : invoice.totalAmount;
      total += amount;
    }
    return _round(total);
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
    // Include exited employees so historical months keep package cost.
    return employee.clientId.trim().isNotEmpty ||
        employee.client.trim().isNotEmpty;
  }

  static double _round(double value) => value.roundToDouble();
}
