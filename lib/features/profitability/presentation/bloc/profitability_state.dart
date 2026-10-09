part of 'profitability_bloc.dart';

enum ProfitabilityStatus { initial, loading, ready, failure }

class ProfitabilityState extends Equatable {
  const ProfitabilityState({
    this.status = ProfitabilityStatus.initial,
    this.employees = const [],
    this.clients = const [],
    this.expenses = const [],
    this.query = '',
    this.errorMessage,
  });

  final ProfitabilityStatus status;
  final List<EmployeeProfitability> employees;
  final List<ClientProfitability> clients;
  final List<Expense> expenses;
  final String query;
  final String? errorMessage;

  List<ClientProfitability> get filteredClients {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return clients;
    return clients
        .where((c) {
          if (c.clientName.toLowerCase().contains(q)) return true;
          return c.employees.any(
            (e) =>
                e.employeeName.toLowerCase().contains(q) ||
                e.employeeId.toLowerCase().contains(q) ||
                e.designation.toLowerCase().contains(q),
          );
        })
        .toList(growable: false);
  }

  ClientProfitability? clientById(String clientId) {
    final id = clientId.trim();
    for (final client in clients) {
      if (client.clientId == id) return client;
    }
    return null;
  }

  double get totalRevenue =>
      filteredClients.fold<double>(0, (s, c) => s + c.billingMonthly);

  double get totalProfit =>
      filteredClients.fold<double>(0, (s, c) => s + c.grossProfit);

  double get totalMarginPercent {
    final revenue = totalRevenue;
    if (revenue <= 0) return 0;
    return ((totalProfit / revenue) * 1000).roundToDouble() / 10;
  }

  ProfitabilityState copyWith({
    ProfitabilityStatus? status,
    List<EmployeeProfitability>? employees,
    List<ClientProfitability>? clients,
    List<Expense>? expenses,
    String? query,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfitabilityState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      clients: clients ?? this.clients,
      expenses: expenses ?? this.expenses,
      query: query ?? this.query,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        employees,
        clients,
        expenses,
        query,
        errorMessage,
      ];
}
