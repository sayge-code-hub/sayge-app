part of 'expenses_bloc.dart';

enum ExpensesStatus { initial, loading, ready, saving, success, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.expenses = const [],
    this.showingForm = false,
    this.editingExpense,
    this.approvingId,
    this.errorMessage,
    this.successMessage,
  });

  final ExpensesStatus status;
  final List<Expense> expenses;
  final bool showingForm;
  final Expense? editingExpense;
  final String? approvingId;
  final String? errorMessage;
  final String? successMessage;

  bool get isEditing => editingExpense != null;

  ExpensesState copyWith({
    ExpensesStatus? status,
    List<Expense>? expenses,
    bool? showingForm,
    Expense? editingExpense,
    String? approvingId,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearApprovingId = false,
    bool clearSuccess = false,
    bool clearEditing = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      showingForm: showingForm ?? this.showingForm,
      editingExpense:
          clearEditing ? null : (editingExpense ?? this.editingExpense),
      approvingId:
          clearApprovingId ? null : (approvingId ?? this.approvingId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        expenses,
        showingForm,
        editingExpense,
        approvingId,
        errorMessage,
        successMessage,
      ];
}
