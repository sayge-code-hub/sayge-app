import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

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

class UpdateExpenseUseCase {
  const UpdateExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, Expense>> call(Expense expense) {
    return _repository.updateExpense(expense);
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

class UploadExpenseReceiptUseCase {
  const UploadExpenseReceiptUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Either<Failure, Expense>> call({
    required String expenseId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
  }) {
    return _repository.uploadReceipt(
      expenseId: expenseId,
      fileName: fileName,
      fileBytes: fileBytes,
      mimeType: mimeType,
    );
  }
}
