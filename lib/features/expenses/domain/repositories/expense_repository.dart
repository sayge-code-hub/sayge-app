import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failures.dart';
import '../entities/expense.dart';

abstract class ExpenseRepository {
  Future<Either<Failure, List<Expense>>> getExpenses();

  Future<Either<Failure, Expense>> addExpense(Expense expense);

  Future<Either<Failure, Expense>> updateExpense(Expense expense);

  Future<Either<Failure, Expense>> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  });

  Future<Either<Failure, Expense>> uploadReceipt({
    required String expenseId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
  });
}
