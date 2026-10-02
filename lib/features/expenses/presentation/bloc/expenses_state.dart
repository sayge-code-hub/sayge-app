part of 'expenses_bloc.dart';

enum ExpensesStatus { initial, loading, ready, saving, success, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.expenses = const [],
    this.showingForm = false,
    this.errorMessage,
  });

  final ExpensesStatus status;
  final List<Expense> expenses;
  final bool showingForm;
  final String? errorMessage;

  ExpensesState copyWith({
    ExpensesStatus? status,
    List<Expense>? expenses,
    bool? showingForm,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      showingForm: showingForm ?? this.showingForm,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, expenses, showingForm, errorMessage];
}
