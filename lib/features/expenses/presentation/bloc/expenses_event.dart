part of 'expenses_bloc.dart';

sealed class ExpensesEvent extends Equatable {
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

class ExpensesStarted extends ExpensesEvent {
  const ExpensesStarted();
}

class ExpenseFormOpened extends ExpensesEvent {
  const ExpenseFormOpened();
}

class ExpenseEditOpened extends ExpensesEvent {
  const ExpenseEditOpened(this.expense);

  final Expense expense;

  @override
  List<Object?> get props => [expense];
}

class ExpenseFormCancelled extends ExpensesEvent {
  const ExpenseFormCancelled();
}

class ExpenseSubmitted extends ExpensesEvent {
  const ExpenseSubmitted(
    this.expense, {
    this.receiptBytes,
    this.receiptFileName,
    this.receiptMimeType,
  });

  final Expense expense;
  final Uint8List? receiptBytes;
  final String? receiptFileName;
  final String? receiptMimeType;

  @override
  List<Object?> get props => [
        expense,
        receiptFileName,
        receiptBytes?.length,
        receiptMimeType,
      ];
}

class ExpenseApprovalChanged extends ExpensesEvent {
  const ExpenseApprovalChanged({
    required this.expenseId,
    required this.status,
  });

  final String expenseId;
  final ExpenseApprovalStatus status;

  @override
  List<Object?> get props => [expenseId, status];
}
