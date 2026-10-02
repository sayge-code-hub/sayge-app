import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/employee.dart';
import '../../../domain/usecases/get_employees.dart';

part 'employees_event.dart';
part 'employees_state.dart';

class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  EmployeesBloc({required this.getEmployeesUseCase})
      : super(const EmployeesState()) {
    on<EmployeesRequested>(_onRequested);
  }

  final GetEmployeesUseCase getEmployeesUseCase;

  Future<void> _onRequested(
    EmployeesRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    emit(state.copyWith(status: EmployeesStatus.loading, clearError: true));

    final result = await getEmployeesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: EmployeesStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (employees) => emit(
        state.copyWith(
          status: EmployeesStatus.success,
          employees: employees,
        ),
      ),
    );
  }
}
