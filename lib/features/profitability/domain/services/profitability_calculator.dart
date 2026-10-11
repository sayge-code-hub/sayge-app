import '../../../expenses/domain/entities/expense.dart';
import '../../../hrms/domain/entities/employee.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../payroll/domain/services/payslip_period.dart';
import '../../../settings/domain/entities/client.dart';
import '../entities/profitability.dart';

/// Profitability from placement margin:
/// invoiced billing − package − approved expenses = profit.
///
/// Client billing uses tax invoices (`taxableAmount`) matched to a company
/// identity (not a billing salutation). Employee `monthlyRate` remains the
/// contracted rate on employee rows and is used only to forecast months that
/// are still in the future.
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
    List<Client> registry = const [],
    DateTime? now,
  }) {
    final index = _CompanyIndex.fromClients(registry);

    // One company is one entity even when billing salutations are separate rows.
    final byClient = <String, List<EmployeeProfitability>>{};
    for (final row in rows) {
      final key = index.keyForEmployee(row);
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
      final clientId =
          index.canonicalId(entry.key) ?? _representativeClientId(list);
      final clientName =
          index.displayName(entry.key) ?? list.first.clientName;
      final billing = _invoicesInMonth(
        invoices,
        companyKey: entry.key,
        index: index,
        year: current.year,
        month: current.month,
      );
      final monthExpenses = _expensesInMonth(
        approved,
        companyKey: entry.key,
        clientKey: clientId,
        clientName: clientName,
        index: index,
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
      companyKey: Expense.companyScopeId,
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
    final seenKeys = <String>{
      for (final c in clients)
        if (c.clientId != Expense.companyScopeId)
          index.keyForClient(clientId: c.clientId, clientName: c.clientName),
    };
    final orphanExpenseKeys = <String, String>{};
    for (final expense in approved) {
      if (expense.isCompanyExpense) continue;
      final key = index.keyForExpense(expense);
      if (seenKeys.contains(key)) continue;
      final name = expense.clientName?.trim() ?? '';
      orphanExpenseKeys[key] = index.displayName(key) ??
          (name.isNotEmpty ? name : 'Client');
    }
    for (final entry in orphanExpenseKeys.entries) {
      final name = entry.value;
      final clientId = index.canonicalId(entry.key) ?? entry.key;
      final billing = _invoicesInMonth(
        invoices,
        companyKey: entry.key,
        index: index,
        year: current.year,
        month: current.month,
      );
      final monthExpenses = _expensesInMonth(
        approved,
        companyKey: entry.key,
        clientKey: clientId,
        clientName: name,
        index: index,
        year: current.year,
        month: current.month,
      );
      clients.add(
        ClientProfitability(
          clientId: clientId,
          clientName: name,
          employeeCount: 0,
          billingMonthly: billing,
          packageMonthly: 0,
          expensesMonthly: monthExpenses,
          grossProfit: _round(billing - monthExpenses),
          marginPercent: billing > 0
              ? _round(((billing - monthExpenses) / billing) * 1000) / 10
              : 0,
          employees: const [],
        ),
      );
      seenKeys.add(entry.key);
    }

    // Clients that only have invoices (no employees / expenses) still appear.
    final orphanInvoiceKeys = <String, String>{};
    for (final invoice in invoices) {
      final key = index.keyForInvoice(invoice);
      if (key == null || key.isEmpty) continue;
      if (seenKeys.contains(key)) continue;
      orphanInvoiceKeys[key] = index.displayName(key) ??
          invoice.buyerCompany.trim();
    }
    for (final entry in orphanInvoiceKeys.entries) {
      final name = entry.value;
      if (name.isEmpty) continue;
      final clientId = index.canonicalId(entry.key) ?? entry.key;
      final billing = _invoicesInMonth(
        invoices,
        companyKey: entry.key,
        index: index,
        year: current.year,
        month: current.month,
      );
      clients.add(
        ClientProfitability(
          clientId: clientId,
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
      seenKeys.add(entry.key);
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
    List<Client> registry = const [],
    DateTime? now,
    int? fyStartYear,
  }) {
    final current = now ?? DateTime.now();
    final months = _monthsThroughCurrent(current);
    if (months.isEmpty) return const [];
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);
    final index = _CompanyIndex.fromClients(registry);

    final rows = [
      for (final period in months.reversed)
        _monthRow(
          client,
          period.year,
          period.month,
          expenses: approved,
          invoices: invoices,
          index: index,
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
    List<Client> registry = const [],
    DateTime? now,
  }) {
    final approved = expenses
        .where((e) => e.approvalStatus == ExpenseApprovalStatus.approved)
        .toList(growable: false);
    final current = now ?? DateTime.now();
    final index = _CompanyIndex.fromClients(registry);
    return [
      for (var i = 0; i < 12; i++)
        _monthRow(
          client,
          i < 9 ? fyStartYear : fyStartYear + 1,
          i < 9 ? i + 4 : i - 8,
          expenses: approved,
          invoices: invoices,
          index: index,
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
    List<Client> registry = const [],
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
        registry: registry,
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
    _CompanyIndex index = const _CompanyIndex.empty(),
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
    final companyKey = index.keyForClient(
      clientId: client.clientId,
      clientName: client.clientName,
    );
    final invoiced = _invoicesInMonth(
      invoices,
      companyKey: companyKey,
      index: index,
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
      companyKey: companyKey,
      clientKey: client.clientId,
      clientName: client.clientName,
      index: index,
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
    required String companyKey,
    _CompanyIndex index = const _CompanyIndex.empty(),
    required int year,
    required int month,
  }) {
    final target = companyKey.trim().toLowerCase();
    if (target.isEmpty ||
        target == Expense.companyScopeLabel.toLowerCase() ||
        target == Expense.companyScopeId) {
      return 0;
    }
    var total = 0.0;
    for (final invoice in invoices) {
      final key = index.keyForInvoice(invoice);
      if (key == null || key != target) continue;
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
    required String companyKey,
    required String clientKey,
    String? clientName,
    _CompanyIndex index = const _CompanyIndex.empty(),
    required int year,
    required int month,
  }) {
    final company = (clientName ?? '').trim().toLowerCase();
    final targetKey = companyKey.trim().toLowerCase();
    var total = 0.0;
    for (final expense in expenses) {
      if (clientKey == Expense.companyScopeId ||
          targetKey == Expense.companyScopeId) {
        if (!expense.isCompanyExpense) continue;
      } else if (expense.isCompanyExpense) {
        continue;
      } else {
        final expenseKey = index.keyForExpense(expense);
        final byCompanyKey = expenseKey == targetKey;
        final byName = company.isNotEmpty &&
            (expense.clientName ?? '').trim().toLowerCase() == company;
        final byId = (expense.clientId ?? '').trim() == clientKey ||
            index.idsForKey(targetKey).contains((expense.clientId ?? '').trim());
        if (!byCompanyKey && !byName && !byId) continue;
      }
      final at = expense.reportingDate?.toLocal();
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

/// Resolves billing salutations / legal-name variants to one company key.
class _CompanyIndex {
  const _CompanyIndex._({
    required this.idToKey,
    required this.nameToKey,
    required this.gstinToKey,
    required this.contactToKey,
    required this.keyToDisplayName,
    required this.keyToCanonicalId,
    required this.keyToIds,
  });

  const _CompanyIndex.empty()
      : idToKey = const {},
        nameToKey = const {},
        gstinToKey = const {},
        contactToKey = const {},
        keyToDisplayName = const {},
        keyToCanonicalId = const {},
        keyToIds = const {};

  final Map<String, String> idToKey;
  final Map<String, String> nameToKey;
  final Map<String, String> gstinToKey;
  final Map<String, String> contactToKey;
  final Map<String, String> keyToDisplayName;
  final Map<String, String> keyToCanonicalId;
  final Map<String, Set<String>> keyToIds;

  bool get isEmpty =>
      idToKey.isEmpty && nameToKey.isEmpty && gstinToKey.isEmpty;

  factory _CompanyIndex.fromClients(List<Client> clients) {
    if (clients.isEmpty) return const _CompanyIndex.empty();

    // Union-find so shared GSTIN merges legal-name variants of one company.
    final parent = <String, String>{};
    String find(String x) {
      parent.putIfAbsent(x, () => x);
      var cur = x;
      while (parent[cur] != cur) {
        parent[cur] = parent[parent[cur]!]!;
        cur = parent[cur]!;
      }
      return cur;
    }

    void union(String a, String b) {
      final pa = find(a);
      final pb = find(b);
      if (pa == pb) return;
      // Prefer the lexicographically smaller key for stability.
      if (pa.compareTo(pb) <= 0) {
        parent[pb] = pa;
      } else {
        parent[pa] = pb;
      }
    }

    final byGstin = <String, String>{};
    for (final client in clients) {
      final key = client.companyKey;
      if (key.isEmpty) continue;
      find(key);
      final gstin = client.gstin.trim().toUpperCase();
      if (gstin.isEmpty) continue;
      final existing = byGstin[gstin];
      if (existing == null) {
        byGstin[gstin] = key;
      } else {
        union(existing, key);
      }
    }

    final idToKey = <String, String>{};
    final nameToKey = <String, String>{};
    final gstinToKey = <String, String>{};
    final contactToKey = <String, String>{};
    final keyToDisplayName = <String, String>{};
    final keyToCanonicalId = <String, String>{};
    final keyToIds = <String, Set<String>>{};
    final ambiguousContacts = <String>{};

    final preferred = Client.uniqueByCompany(clients);

    for (final client in clients) {
      final rawKey = client.companyKey;
      if (rawKey.isEmpty) continue;
      final key = find(rawKey);
      idToKey[client.id] = key;
      nameToKey[rawKey] = key;
      (keyToIds[key] ??= {}).add(client.id);

      final gstin = client.gstin.trim().toUpperCase();
      if (gstin.isNotEmpty) gstinToKey[gstin] = key;

      final contact = _normalizeContact(client.contactName);
      if (contact.isNotEmpty) {
        final existing = contactToKey[contact];
        if (existing == null) {
          contactToKey[contact] = key;
        } else if (existing != key) {
          ambiguousContacts.add(contact);
        }
      }

      keyToDisplayName.putIfAbsent(key, () => client.name.trim());
    }

    for (final contact in ambiguousContacts) {
      contactToKey.remove(contact);
    }

    for (final client in preferred) {
      final key = idToKey[client.id];
      if (key == null) continue;
      keyToCanonicalId[key] = client.id;
      keyToDisplayName[key] = client.name.trim();
    }

    return _CompanyIndex._(
      idToKey: idToKey,
      nameToKey: nameToKey,
      gstinToKey: gstinToKey,
      contactToKey: contactToKey,
      keyToDisplayName: keyToDisplayName,
      keyToCanonicalId: keyToCanonicalId,
      keyToIds: keyToIds,
    );
  }

  String keyForEmployee(EmployeeProfitability row) {
    return keyForClient(clientId: row.clientId, clientName: row.clientName);
  }

  String keyForClient({String? clientId, String? clientName}) {
    final id = (clientId ?? '').trim();
    if (id == Expense.companyScopeId) return Expense.companyScopeId;
    if (id.isNotEmpty) {
      final byId = idToKey[id];
      if (byId != null) return byId;
    }
    final name = (clientName ?? '').trim().toLowerCase();
    if (name.isNotEmpty) {
      final byName = nameToKey[name];
      if (byName != null) return byName;
      return name;
    }
    if (id.isNotEmpty) return id;
    return '__unassigned__';
  }

  String? keyForInvoice(Invoice invoice) {
    final company = invoice.buyerCompany.trim().toLowerCase();
    if (company.isNotEmpty) {
      final byName = nameToKey[company];
      if (byName != null) return byName;
    }

    final gstin = invoice.buyerGstin.trim().toUpperCase();
    if (gstin.isNotEmpty) {
      final byGstin = gstinToKey[gstin];
      if (byGstin != null) return byGstin;
    }

    for (final raw in [invoice.buyerContact, invoice.buyerName]) {
      final contact = _normalizeContact(raw);
      if (contact.isEmpty) continue;
      final byContact = contactToKey[contact];
      if (byContact != null) return byContact;
    }

    if (company.isNotEmpty) return company;
    return null;
  }

  String keyForExpense(Expense expense) {
    if (expense.isCompanyExpense) return Expense.companyScopeId;
    final id = (expense.clientId ?? '').trim();
    if (id.isNotEmpty) {
      final byId = idToKey[id];
      if (byId != null) return byId;
    }
    final name = (expense.clientName ?? '').trim().toLowerCase();
    if (name.isNotEmpty) {
      final byName = nameToKey[name];
      if (byName != null) return byName;
      return name;
    }
    return id.isNotEmpty ? id : '__unassigned__';
  }

  String? displayName(String key) => keyToDisplayName[key];

  String? canonicalId(String key) => keyToCanonicalId[key];

  Set<String> idsForKey(String key) => keyToIds[key] ?? const {};

  static String _normalizeContact(String raw) {
    var s = raw.trim().toLowerCase();
    const prefixes = [
      'mr. ',
      'mrs. ',
      'ms. ',
      'mr ',
      'mrs ',
      'ms ',
    ];
    for (final prefix in prefixes) {
      if (s.startsWith(prefix)) {
        s = s.substring(prefix.length);
        break;
      }
    }
    return s.trim();
  }
}
