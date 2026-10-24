import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';

import '../../../domain/entities/expense_category.dart';
import '../../../domain/usecases/expense_category_usecases.dart';

part 'expense_categories_event.dart';
part 'expense_categories_state.dart';

class ExpenseCategoriesBloc
    extends Bloc<ExpenseCategoriesEvent, ExpenseCategoriesState> {
  ExpenseCategoriesBloc({
    required this.getCategories,
    required this.addCategory,
    required this.renameCategory,
    required this.deleteCategory,
  }) : super(const ExpenseCategoriesState()) {
    on<ExpenseCategoriesStarted>(_onStarted);
    on<ExpenseCategoryAdded>(_onAdded);
    on<ExpenseCategoryRenamed>(_onRenamed);
    on<ExpenseCategoryDeleted>(_onDeleted);
  }

  final GetExpenseCategoriesUseCase getCategories;
  final AddExpenseCategoryUseCase addCategory;
  final RenameExpenseCategoryUseCase renameCategory;
  final DeleteExpenseCategoryUseCase deleteCategory;

  Future<void> _onStarted(
    ExpenseCategoriesStarted event,
    Emitter<ExpenseCategoriesState> emit,
  ) async {
    emit(
      state.copyWith(status: ExpenseCategoriesStatus.loading, clearError: true),
    );
    final result = await getCategories();
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ExpenseCategoriesStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (categories) => emit(
        state.copyWith(
          status: ExpenseCategoriesStatus.ready,
          categories: categories,
        ),
      ),
    );
  }

  Future<void> _onAdded(
    ExpenseCategoryAdded event,
    Emitter<ExpenseCategoriesState> emit,
  ) async {
    await _mutate(emit, () => addCategory(event.name));
  }

  Future<void> _onRenamed(
    ExpenseCategoryRenamed event,
    Emitter<ExpenseCategoriesState> emit,
  ) async {
    await _mutate(emit, () => renameCategory(id: event.id, name: event.name));
  }

  Future<void> _onDeleted(
    ExpenseCategoryDeleted event,
    Emitter<ExpenseCategoriesState> emit,
  ) async {
    await _mutate(emit, () => deleteCategory(event.id));
  }

  Future<void> _mutate(
    Emitter<ExpenseCategoriesState> emit,
    Future<Either<Failure, List<ExpenseCategory>>> Function() action,
  ) async {
    emit(state.copyWith(saving: true, clearError: true));
    final result = await action();
    result.fold(
      (failure) =>
          emit(state.copyWith(saving: false, errorMessage: failure.message)),
      (categories) => emit(
        state.copyWith(
          status: ExpenseCategoriesStatus.ready,
          saving: false,
          categories: categories,
        ),
      ),
    );
  }
}
