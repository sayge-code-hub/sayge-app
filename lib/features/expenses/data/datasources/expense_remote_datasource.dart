import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/expense.dart';
import '../models/expense_model.dart';

abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseModel>> getExpenses();

  Future<ExpenseModel> addExpense(Expense expense);
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  ExpenseRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'expenses';

  @override
  Future<List<ExpenseModel>> getExpenses() async {
    try {
      final rows =
          await _client.from(_table).select().order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load expenses.');
    }
  }

  @override
  Future<ExpenseModel> addExpense(Expense expense) async {
    final madeFor = expense.madeFor.trim();
    final paidFrom = expense.paidFrom.trim();
    final category = expense.category.trim();
    if (madeFor.isEmpty) {
      throw const ServerException('Expense made for is required.');
    }
    if (expense.amount <= 0) {
      throw const ServerException('Amount must be greater than zero.');
    }
    if (paidFrom.isEmpty) {
      throw const ServerException('Paid from is required.');
    }
    if (!Expense.categories.contains(category)) {
      throw const ServerException('Select a valid category.');
    }

    final id = expense.id.trim().isEmpty
        ? 'exp_${DateTime.now().millisecondsSinceEpoch}'
        : expense.id.trim();

    try {
      final row = await _client
          .from(_table)
          .insert(
            ExpenseModel(
              id: id,
              madeFor: madeFor,
              amount: expense.amount,
              paidFrom: paidFrom,
              category: category,
            ).toJson(),
          )
          .select()
          .single();
      return ExpenseModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save expense.');
    }
  }
}
