part of 'employees_bloc.dart';

abstract class EmployeesEvent extends Equatable {
  const EmployeesEvent();

  @override
  List<Object?> get props => [];
}

class EmployeesRequested extends EmployeesEvent {
  const EmployeesRequested();
}
