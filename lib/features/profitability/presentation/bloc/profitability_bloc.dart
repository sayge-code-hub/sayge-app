import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/usecases/expense_usecases.dart';
import '../../../hrms/domain/usecases/get_employees.dart';
import '../../domain/entities/profitability.dart';
import '../../domain/services/profitability_calculator.dart';

part 'profitability_event.dart';
part 'profitability_state.dart';

class ProfitabilityBloc extends Bloc<ProfitabilityEvent, ProfitabilityState> {
  ProfitabilityBloc({
    required this.getEmployeesUseCase,
    required this.getExpensesUseCase,
  }) : super(const ProfitabilityState()) {
    on<ProfitabilityStarted>(_onStarted);
    on<ProfitabilitySearchChanged>(_onSearchChanged);
  }

  final GetEmployeesUseCase getEmployeesUseCase;
  final GetExpensesUseCase getExpensesUseCase;

  Future<void> _onStarted(
    ProfitabilityStarted event,
    Emitter<ProfitabilityState> emit,
  ) async {
    emit(state.copyWith(status: ProfitabilityStatus.loading, clearError: true));

    final employeesResult = await getEmployeesUseCase();
    final expensesResult = await getExpensesUseCase();

    List<Expense> expenses = const [];
    expensesResult.fold((_) {}, (list) => expenses = list);

    employeesResult.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfitabilityStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (employees) {
        final rows = ProfitabilityCalculator.forEmployees(employees);
        final clients = ProfitabilityCalculator.rollUpByClient(
          rows,
          expenses: expenses,
        );
        emit(
          state.copyWith(
            status: ProfitabilityStatus.ready,
            employees: rows,
            clients: clients,
            expenses: expenses,
          ),
        );
      },
    );
  }

  void _onSearchChanged(
    ProfitabilitySearchChanged event,
    Emitter<ProfitabilityState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }
}
