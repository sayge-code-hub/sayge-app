import 'entities/employee.dart';

/// Status chips on the employees list.
enum EmployeeListStatusFilter {
  all,
  active,
  draft,
  exited,
}

/// Pure predicates / labels for the employees list (unit-tested).
abstract final class EmployeeListFilters {
  static bool matchesStatus(Employee employee, EmployeeListStatusFilter filter) {
    switch (filter) {
      case EmployeeListStatusFilter.all:
        return true;
      case EmployeeListStatusFilter.active:
        return !employee.isDraft && employee.isActive;
      case EmployeeListStatusFilter.draft:
        return employee.isDraft;
      case EmployeeListStatusFilter.exited:
        return !employee.isActive || employee.dateOfExit != null;
    }
  }

  static bool matchesClient(Employee employee, String? clientFilter) {
    final selected = clientFilter?.trim() ?? '';
    if (selected.isEmpty) return true;
    return employee.client.trim() == selected;
  }

  static bool matchesSearch(Employee employee, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return employee.employeeName.toLowerCase().contains(q) ||
        employee.employeeId.toLowerCase().contains(q) ||
        employee.designation.toLowerCase().contains(q) ||
        employee.client.toLowerCase().contains(q);
  }

  static List<Employee> apply({
    required List<Employee> employees,
    required EmployeeListStatusFilter status,
    String? client,
    String query = '',
  }) {
    return employees
        .where(
          (e) =>
              matchesStatus(e, status) &&
              matchesClient(e, client) &&
              matchesSearch(e, query),
        )
        .toList(growable: false);
  }

  /// Distinct non-empty client names from [employees], sorted.
  static List<String> distinctClients(List<Employee> employees) {
    final set = <String>{};
    for (final e in employees) {
      final name = e.client.trim();
      if (name.isNotEmpty) set.add(name);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Badge / table status label for list rows.
  static String statusLabel(Employee employee) {
    if (employee.isDraft) return 'Draft';
    if (!employee.isActive || employee.dateOfExit != null) return 'Exited';
    return 'Active';
  }

  static bool isExited(Employee employee) =>
      !employee.isActive || employee.dateOfExit != null;
}
