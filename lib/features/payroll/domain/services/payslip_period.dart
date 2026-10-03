import '../../../hrms/domain/entities/employee.dart';

/// Shared rules for which payroll months can produce a salary slip.
abstract final class PayslipPeriod {
  /// Company payroll start — no slips before this month.
  static final DateTime earliestAllowed = DateTime(2026, 4, 1);

  static DateTime monthOf(DateTime date) => DateTime(date.year, date.month, 1);

  /// Last fully completed calendar month (current month is excluded).
  static DateTime latestAvailable([DateTime? now]) {
    final current = now ?? DateTime.now();
    return DateTime(current.year, current.month - 1, 1);
  }

  /// First month an employee may download a slip for.
  static DateTime earliestForEmployee(DateTime dateOfJoining) {
    final joinMonth = monthOf(dateOfJoining);
    return joinMonth.isAfter(earliestAllowed) ? joinMonth : earliestAllowed;
  }

  /// Month choices for admin payroll (company start → last completed month).
  static List<DateTime> optionsForAdmin([DateTime? now]) {
    final start = earliestAllowed;
    final end = latestAvailable(now);
    if (start.isAfter(end)) return const [];

    final options = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      options.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return options;
  }

  /// Month choices for employee self-service (join month → last completed month).
  static List<DateTime> optionsForEmployee(DateTime dateOfJoining) {
    final start = earliestForEmployee(dateOfJoining);
    final end = latestAvailable();
    if (start.isAfter(end)) return const [];

    final options = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      options.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return options;
  }

  /// Whether [employee] had joined by the start of the payroll month.
  static bool hasJoinedBy(
    Employee employee, {
    required int month,
    required int year,
  }) {
    final period = DateTime(year, month, 1);
    return !period.isBefore(monthOf(employee.dateOfJoining));
  }

  /// Whether [employee] may receive a slip for the given payroll month.
  static bool isEligible(
    Employee employee, {
    required int month,
    required int year,
  }) {
    final period = DateTime(year, month, 1);
    if (period.isBefore(earliestAllowed)) return false;
    if (period.isAfter(latestAvailable())) return false;
    return hasJoinedBy(employee, month: month, year: year);
  }
}
