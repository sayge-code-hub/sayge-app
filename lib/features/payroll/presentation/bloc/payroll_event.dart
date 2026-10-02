part of 'payroll_bloc.dart';

abstract class PayrollEvent extends Equatable {
  const PayrollEvent();

  @override
  List<Object?> get props => [];
}

class PayrollStarted extends PayrollEvent {
  const PayrollStarted();
}

class PayrollMonthChanged extends PayrollEvent {
  const PayrollMonthChanged({required this.month, required this.year});

  final int month;
  final int year;

  @override
  List<Object?> get props => [month, year];
}

class PayrollEmployeeToggled extends PayrollEvent {
  const PayrollEmployeeToggled(this.employeeId);

  final String employeeId;

  @override
  List<Object?> get props => [employeeId];
}

class PayrollSelectAllToggled extends PayrollEvent {
  const PayrollSelectAllToggled();
}

class PayrollDownloadSelected extends PayrollEvent {
  const PayrollDownloadSelected();
}

class PayrollDownloadAll extends PayrollEvent {
  const PayrollDownloadAll();
}
