import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/expense.dart';
import '../../domain/usecases/expense_usecases.dart';

part 'expenses_event.dart';
part 'expenses_state.dart';

class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc({
    required this.getExpensesUseCase,
    required this.addExpenseUseCase,
    required this.setExpenseApprovalUseCase,
  }) : super(const ExpensesState()) {
    on<ExpensesStarted>(_onStarted);
    on<ExpenseFormOpened>(_onFormOpened);
    on<ExpenseFormCancelled>(_onFormCancelled);
    on<ExpenseSubmitted>(_onSubmitted);
    on<ExpenseApprovalChanged>(_onApprovalChanged);
  }

  final GetExpensesUseCase getExpensesUseCase;
  final AddExpenseUseCase addExpenseUseCase;
  final SetExpenseApprovalUseCase setExpenseApprovalUseCase;

  Future<void> _onStarted(
    ExpensesStarted event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(status: ExpensesStatus.loading, clearError: true));
    final result = await getExpensesUseCase();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpensesStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (expenses) => emit(
        state.copyWith(
          status: ExpensesStatus.ready,
          expenses: expenses,
          showingForm: false,
        ),
      ),
    );
  }

  void _onFormOpened(ExpenseFormOpened event, Emitter<ExpensesState> emit) {
    emit(
      state.copyWith(
        showingForm: true,
        status: ExpensesStatus.ready,
        clearError: true,
      ),
    );
  }

  void _onFormCancelled(
    ExpenseFormCancelled event,
    Emitter<ExpensesState> emit,
  ) {
    emit(
      state.copyWith(
        showingForm: false,
        status: ExpensesStatus.ready,
        clearError: true,
      ),
    );
  }

  Future<void> _onSubmitted(
    ExpenseSubmitted event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(status: ExpensesStatus.saving, clearError: true));
    final result = await addExpenseUseCase(event.expense);
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ExpensesStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (_) async {
        final latest = await getExpensesUseCase();
        latest.fold(
          (failure) => emit(
            state.copyWith(
              status: ExpensesStatus.success,
              showingForm: false,
              successMessage: 'Expense saved',
              errorMessage: failure.message,
            ),
          ),
          (expenses) => emit(
            state.copyWith(
              status: ExpensesStatus.success,
              expenses: expenses,
              showingForm: false,
              successMessage: 'Expense saved',
            ),
          ),
        );
      },
    );
  }

  Future<void> _onApprovalChanged(
    ExpenseApprovalChanged event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(
      state.copyWith(
        status: ExpensesStatus.saving,
        approvingId: event.expenseId,
        clearError: true,
      ),
    );
    final result = await setExpenseApprovalUseCase(
      expenseId: event.expenseId,
      status: event.status,
    );
    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ExpensesStatus.failure,
            errorMessage: failure.message,
            clearApprovingId: true,
          ),
        );
        emit(
          state.copyWith(
            status: ExpensesStatus.ready,
            clearApprovingId: true,
          ),
        );
      },
      (updated) async {
        final next = state.expenses
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
        emit(
          state.copyWith(
            status: ExpensesStatus.success,
            expenses: next,
            successMessage: event.status == ExpenseApprovalStatus.approved
                ? 'Expense approved'
                : 'Expense rejected',
            clearApprovingId: true,
          ),
        );
      },
    );
  }
}
