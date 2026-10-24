import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/expense.dart';
import '../../domain/usecases/expense_usecases.dart';

part 'expenses_event.dart';
part 'expenses_state.dart';

class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  ExpensesBloc({
    required this.getExpensesUseCase,
    required this.addExpenseUseCase,
    required this.updateExpenseUseCase,
    required this.setExpenseApprovalUseCase,
    required this.uploadExpenseReceiptUseCase,
  }) : super(const ExpensesState()) {
    on<ExpensesStarted>(_onStarted);
    on<ExpenseFormOpened>(_onFormOpened);
    on<ExpenseEditOpened>(_onEditOpened);
    on<ExpenseFormCancelled>(_onFormCancelled);
    on<ExpenseSubmitted>(_onSubmitted);
    on<ExpenseApprovalChanged>(_onApprovalChanged);
  }

  final GetExpensesUseCase getExpensesUseCase;
  final AddExpenseUseCase addExpenseUseCase;
  final UpdateExpenseUseCase updateExpenseUseCase;
  final SetExpenseApprovalUseCase setExpenseApprovalUseCase;
  final UploadExpenseReceiptUseCase uploadExpenseReceiptUseCase;

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
          clearEditing: true,
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
        clearEditing: true,
      ),
    );
  }

  void _onEditOpened(ExpenseEditOpened event, Emitter<ExpensesState> emit) {
    if (event.expense.approvalStatus != ExpenseApprovalStatus.pending) {
      emit(
        state.copyWith(
          status: ExpensesStatus.failure,
          errorMessage: 'Only pending expenses can be edited.',
        ),
      );
      emit(state.copyWith(status: ExpensesStatus.ready, clearError: true));
      return;
    }
    emit(
      state.copyWith(
        showingForm: true,
        status: ExpensesStatus.ready,
        editingExpense: event.expense,
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
        clearEditing: true,
      ),
    );
  }

  Future<void> _onSubmitted(
    ExpenseSubmitted event,
    Emitter<ExpensesState> emit,
  ) async {
    emit(state.copyWith(status: ExpensesStatus.saving, clearError: true));
    final editing = state.editingExpense;
    final result = editing == null
        ? await addExpenseUseCase(event.expense)
        : await updateExpenseUseCase(
            Expense(
              id: editing.id,
              madeFor: event.expense.madeFor,
              amount: event.expense.amount,
              paidFrom: event.expense.paidFrom,
              category: event.expense.category,
              clientId: event.expense.clientId,
              clientName: event.expense.clientName,
              approvalStatus: editing.approvalStatus,
              expenseDate: event.expense.expenseDate,
              receiptPath: editing.receiptPath,
              receiptName: editing.receiptName,
              createdAt: editing.createdAt,
              createdBy: editing.createdBy,
            ),
          );

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            status: ExpensesStatus.failure,
            errorMessage: failure.message,
          ),
        );
      },
      (saved) async {
        Expense finalExpense = saved;
        final receipt = event.receiptBytes;
        final receiptName = event.receiptFileName?.trim() ?? '';
        if (receipt != null && receipt.isNotEmpty && receiptName.isNotEmpty) {
          final upload = await uploadExpenseReceiptUseCase(
            expenseId: saved.id,
            fileName: receiptName,
            fileBytes: receipt,
            mimeType: event.receiptMimeType ?? 'application/octet-stream',
          );
          final uploadFailed = upload.fold((failure) => failure.message, (
            updated,
          ) {
            finalExpense = updated;
            return null;
          });
          if (uploadFailed != null) {
            emit(
              state.copyWith(
                status: ExpensesStatus.failure,
                // Keep the form open so the error is visible and the user can retry.
                showingForm: true,
                editingExpense: finalExpense,
                errorMessage:
                    'Expense saved, but the receipt failed to upload: $uploadFailed',
                expenses: [
                  for (final e in state.expenses)
                    if (e.id == finalExpense.id) finalExpense else e,
                  if (!state.expenses.any((e) => e.id == finalExpense.id))
                    finalExpense,
                ],
              ),
            );
            return;
          }
        }

        final latest = await getExpensesUseCase();
        latest.fold(
          (failure) => emit(
            state.copyWith(
              status: ExpensesStatus.success,
              showingForm: false,
              clearEditing: true,
              successMessage: 'Expense saved',
              expenses: [
                for (final e in state.expenses)
                  if (e.id == finalExpense.id) finalExpense else e,
                if (!state.expenses.any((e) => e.id == finalExpense.id))
                  finalExpense,
              ],
              errorMessage: failure.message,
            ),
          ),
          (expenses) => emit(
            state.copyWith(
              status: ExpensesStatus.success,
              expenses: expenses,
              showingForm: false,
              clearEditing: true,
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
          state.copyWith(status: ExpensesStatus.ready, clearApprovingId: true),
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
