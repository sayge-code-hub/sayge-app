import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_category.dart';
import '../repositories/expense_category_repository.dart';

class GetExpenseCategoriesUseCase {
  const GetExpenseCategoriesUseCase(this._repository);

  final ExpenseCategoryRepository _repository;

  Future<Either<Failure, List<ExpenseCategory>>> call() {
    return _repository.listCategories();
  }
}

class AddExpenseCategoryUseCase {
  const AddExpenseCategoryUseCase(this._repository);

  final ExpenseCategoryRepository _repository;

  Future<Either<Failure, List<ExpenseCategory>>> call(String name) {
    return _repository.addCategory(name);
  }
}

class RenameExpenseCategoryUseCase {
  const RenameExpenseCategoryUseCase(this._repository);

  final ExpenseCategoryRepository _repository;

  Future<Either<Failure, List<ExpenseCategory>>> call({
    required String id,
    required String name,
  }) {
    return _repository.renameCategory(id: id, name: name);
  }
}

class DeleteExpenseCategoryUseCase {
  const DeleteExpenseCategoryUseCase(this._repository);

  final ExpenseCategoryRepository _repository;

  Future<Either<Failure, List<ExpenseCategory>>> call(String id) {
    return _repository.deleteCategory(id);
  }
}
