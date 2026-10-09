import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/expense.dart';
import '../models/expense_model.dart';

abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseModel>> getExpenses();

  Future<ExpenseModel> addExpense(Expense expense);

  Future<ExpenseModel> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  });
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  ExpenseRemoteDataSourceImpl({
    SupabaseClient? client,
    this._authSession,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AuthSession? _authSession;

  static const _table = 'expenses';
  static const _selectWithClient = '*, clients(id, name)';

  @override
  Future<List<ExpenseModel>> getExpenses() async {
    try {
      var query = _client.from(_table).select(_selectWithClient);

      final user = _authSession?.user;
      if (AppAccess.isEmployeeOnly(user)) {
        final uid = _client.auth.currentUser?.id ?? user!.id;
        query = query.eq('created_by', uid);
      }

      final rows = await query.order('created_at', ascending: false);
      return (rows as List<dynamic>)
          .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      // Older DBs without created_by: staff still see all; employees see none
      // until the column / RLS migration is applied.
      if (e.message.contains('created_by') &&
          AppAccess.isEmployeeOnly(_authSession?.user)) {
        return const [];
      }
      if (e.message.contains('created_by') &&
          AppAccess.isStaff(_authSession?.user)) {
        final rows = await _client
            .from(_table)
            .select(_selectWithClient)
            .order('created_at', ascending: false);
        return (rows as List<dynamic>)
            .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
            .toList();
      }
      // Fallback before client_id / join migration.
      if (e.message.contains('client_id') || e.message.contains('clients')) {
        final rows = await _client
            .from(_table)
            .select()
            .order('created_at', ascending: false);
        return (rows as List<dynamic>)
            .map((row) => ExpenseModel.fromJson(row as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
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
    final uid =
        _client.auth.currentUser?.id ?? _authSession?.user?.id;

    final clientId = expense.isCompanyExpense ? null : expense.clientId?.trim();

    try {
      final payload = ExpenseModel(
        id: id,
        madeFor: madeFor,
        amount: expense.amount,
        paidFrom: paidFrom,
        category: category,
        clientId: clientId,
        clientName: expense.clientName,
        createdBy: uid,
      ).toJson();

      final row = await _client
          .from(_table)
          .insert(payload)
          .select(_selectWithClient)
          .single();
      return ExpenseModel.fromJson(row);
    } on PostgrestException catch (e) {
      // Fallback if created_by column is not migrated yet.
      if (e.message.contains('created_by')) {
        final row = await _client
            .from(_table)
            .insert(
              ExpenseModel(
                id: id,
                madeFor: madeFor,
                amount: expense.amount,
                paidFrom: paidFrom,
                category: category,
                clientId: clientId,
              ).toJson(),
            )
            .select(_selectWithClient)
            .single();
        return ExpenseModel.fromJson(row);
      }
      // Fallback before client_id migration.
      if (e.message.contains('client_id')) {
        final row = await _client
            .from(_table)
            .insert(
              ExpenseModel(
                id: id,
                madeFor: madeFor,
                amount: expense.amount,
                paidFrom: paidFrom,
                category: category,
                createdBy: uid,
              ).toJson()
                ..remove('client_id'),
            )
            .select()
            .single();
        return ExpenseModel.fromJson(row);
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save expense.');
    }
  }

  @override
  Future<ExpenseModel> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException('Only owner or admin can approve expenses.');
    }
    final id = expenseId.trim();
    if (id.isEmpty) {
      throw const ServerException('Expense id is required.');
    }
    if (status == ExpenseApprovalStatus.pending) {
      throw const ServerException('Choose approved or rejected.');
    }

    try {
      final row = await _client
          .from(_table)
          .update({
            'approval_status': status.dbValue,
            'approved_by': _client.auth.currentUser?.id,
            'approved_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select(_selectWithClient)
          .single();
      return ExpenseModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update approval.');
    }
  }
}
