import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense.dart';
import '../repositories/expense_repository.dart';

class GetExpensesUseCase {
  const GetExpensesUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, List<Expense>>> call() => _repository.getExpenses();
}

class AddExpenseUseCase {
  const AddExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, Expense>> call(Expense expense) {
    return _repository.addExpense(expense);
  }
}

class SetExpenseApprovalUseCase {
  const SetExpenseApprovalUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, Expense>> call({
    required String expenseId,
    required ExpenseApprovalStatus status,
  }) {
    return _repository.setApprovalStatus(
      expenseId: expenseId,
      status: status,
    );
  }
}
