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
  final List<Employee> employees;
  final Set<String> selectedIds;
  final int month;
  final int year;
  final String? errorMessage;

  bool get allSelected =>
      employees.isNotEmpty && selectedIds.length == employees.length;

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
