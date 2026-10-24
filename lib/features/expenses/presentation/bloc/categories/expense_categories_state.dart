part of 'expense_categories_bloc.dart';

enum ExpenseCategoriesStatus { initial, loading, ready, failure }

class ExpenseCategoriesState extends Equatable {
  const ExpenseCategoriesState({
    this.status = ExpenseCategoriesStatus.initial,
    this.categories = const [],
    this.saving = false,
    this.errorMessage,
  });

  final ExpenseCategoriesStatus status;
  final List<ExpenseCategory> categories;
  final bool saving;
  final String? errorMessage;

  ExpenseCategoriesState copyWith({
    ExpenseCategoriesStatus? status,
    List<ExpenseCategory>? categories,
    bool? saving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpenseCategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      saving: saving ?? this.saving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, categories, saving, errorMessage];
}
