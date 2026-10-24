import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense_category.dart';

abstract class ExpenseCategoryRepository {
  Future<Either<Failure, List<ExpenseCategory>>> listCategories();

  Future<Either<Failure, List<ExpenseCategory>>> addCategory(String name);

  Future<Either<Failure, List<ExpenseCategory>>> renameCategory({
    required String id,
    required String name,
  });

  Future<Either<Failure, List<ExpenseCategory>>> deleteCategory(String id);
}
