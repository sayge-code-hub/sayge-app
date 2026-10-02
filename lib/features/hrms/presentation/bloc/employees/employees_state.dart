part of 'employees_bloc.dart';

enum EmployeesStatus { initial, loading, success, failure }

class EmployeesState extends Equatable {
  const EmployeesState({
    this.status = EmployeesStatus.initial,
    this.employees = const [],
    this.errorMessage,
  });

  final EmployeesStatus status;
  final List<Employee> employees;
  final String? errorMessage;

  EmployeesState copyWith({
    EmployeesStatus? status,
    List<Employee>? employees,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeesState(
      status: status ?? this.status,
      employees: employees ?? this.employees,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, employees, errorMessage];
}
