part of 'expenses_bloc.dart';

enum ExpensesStatus { initial, loading, ready, saving, success, failure }

class ExpensesState extends Equatable {
  const ExpensesState({
    this.status = ExpensesStatus.initial,
    this.expenses = const [],
    this.showingForm = false,
    this.approvingId,
    this.errorMessage,
    this.successMessage,
  });

  final ExpensesStatus status;
  final List<Expense> expenses;
  final bool showingForm;
  final String? approvingId;
  final String? errorMessage;
  final String? successMessage;

  ExpensesState copyWith({
    ExpensesStatus? status,
    List<Expense>? expenses,
    bool? showingForm,
    String? approvingId,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearApprovingId = false,
    bool clearSuccess = false,
  }) {
    return ExpensesState(
      status: status ?? this.status,
      expenses: expenses ?? this.expenses,
      showingForm: showingForm ?? this.showingForm,
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
        approvingId,
        errorMessage,
        successMessage,
      ];
}
