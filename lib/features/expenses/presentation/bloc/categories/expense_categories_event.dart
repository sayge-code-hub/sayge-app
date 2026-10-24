part of 'expense_categories_bloc.dart';

sealed class ExpenseCategoriesEvent extends Equatable {
  const ExpenseCategoriesEvent();

  @override
  List<Object?> get props => [];
}

class ExpenseCategoriesStarted extends ExpenseCategoriesEvent {
  const ExpenseCategoriesStarted();
}

class ExpenseCategoryAdded extends ExpenseCategoriesEvent {
  const ExpenseCategoryAdded(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}

class ExpenseCategoryRenamed extends ExpenseCategoriesEvent {
  const ExpenseCategoryRenamed({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

class ExpenseCategoryDeleted extends ExpenseCategoriesEvent {
  const ExpenseCategoryDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
