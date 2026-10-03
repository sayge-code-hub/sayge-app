part of 'payroll_bloc.dart';

enum PayrollStatus { initial, loading, ready, generating, failure }

class PayrollState extends Equatable {
  const PayrollState({
    this.status = PayrollStatus.initial,
    this.employees = const [],
    this.selectedIds = const {},
    required this.month,
    required this.year,
    this.errorMessage,
  });

  final PayrollStatus status;
  /// All active employees (unfiltered). Use [employeesForPeriod] in the UI.
  final List<Employee> employees;
  final Set<String> selectedIds;
  final int month;
  final int year;
  final String? errorMessage;

  /// Active employees who had joined by the selected payroll month.
  List<Employee> get employeesForPeriod => employees
      .where(
        (e) => PayslipPeriod.hasJoinedBy(e, month: month, year: year),
      )
      .toList(growable: false);

  bool get allSelected {
    final visible = employeesForPeriod;
    return visible.isNotEmpty &&
        selectedIds.length == visible.length &&
        visible.every((e) => selectedIds.contains(e.employeeId));
  }

  PayrollState copyWith({
    PayrollStatus? status,
    List<Employee>? employees,
    Set<String>? selectedIds,
    int? month,
    int? year,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PayrollState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      selectedIds: selectedIds ?? this.selectedIds,
      month: month ?? this.month,
      year: year ?? this.year,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        employees,
        selectedIds,
        month,
        year,
        errorMessage,
      ];
}
