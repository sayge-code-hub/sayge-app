import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<Either<Failure, List<Expense>>> getExpenses();

  Future<Either<Failure, Expense>> addExpense(Expense expense);

  Future<Either<Failure, Expense>> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  });
}
