import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/app_storage_urls.dart';
import '../../domain/entities/expense.dart';
import '../models/expense_model.dart';

abstract class ExpenseRemoteDataSource {
  Future<List<ExpenseModel>> getExpenses();

  Future<ExpenseModel> addExpense(Expense expense);

  Future<ExpenseModel> updateExpense(Expense expense);

  Future<ExpenseModel> setApprovalStatus({
    required String expenseId,
    required ExpenseApprovalStatus status,
  });

  Future<ExpenseModel> uploadReceipt({
    required String expenseId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
  });

  Future<String> receiptDownloadUrl(String receiptPath);
}

class ExpenseRemoteDataSourceImpl implements ExpenseRemoteDataSource {
  ExpenseRemoteDataSourceImpl({SupabaseClient? client, this._authSession})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AuthSession? _authSession;

  static const _table = 'expenses';

  void _throwCategoryConstraint(PostgrestException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == '23514' && message.contains('category')) {
      throw const ServerException(
        'That category is not allowed yet. Run supabase/expense_categories.sql '
        'in the Supabase SQL editor, then try again.',
      );
    }
  }

  static const _selectWithClient = '*, clients(id, name)';
  static const _bucket = 'documents';

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
      if (e.message.contains('created_by') ||
          e.message.contains('client_id') ||
          e.message.contains('clients')) {
        throw const ServerException(
          'Expense schema is incomplete. Run supabase/ops_completeness_pack.sql '
          'and supabase/security_hardening.sql in the Supabase SQL editor.',
        );
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
    if (category.isEmpty) {
      throw const ServerException('Select a category.');
    }

    final id = expense.id.trim().isEmpty
        ? 'exp_${DateTime.now().millisecondsSinceEpoch}'
        : expense.id.trim();
    final uid = _client.auth.currentUser?.id ?? _authSession?.user?.id;

    final clientId = expense.isCompanyExpense ? null : expense.clientId?.trim();
    final expenseDate = expense.expenseDate ?? DateTime.now();

    try {
      final payload = ExpenseModel(
        id: id,
        madeFor: madeFor,
        amount: expense.amount,
        paidFrom: paidFrom,
        category: category,
        clientId: clientId,
        clientName: expense.clientName,
        expenseDate: expenseDate,
        receiptPath: expense.receiptPath,
        receiptName: expense.receiptName,
        createdBy: uid,
      ).toJson();

      final row = await _client
          .from(_table)
          .insert(payload)
          .select(_selectWithClient)
          .single();
      return ExpenseModel.fromJson(row);
    } on PostgrestException catch (e) {
      _throwCategoryConstraint(e);
      if (e.message.contains('expense_date') ||
          e.message.contains('receipt_') ||
          e.message.contains('created_by') ||
          e.message.contains('client_id')) {
        throw const ServerException(
          'Expense schema is incomplete. Run supabase/ops_completeness_pack.sql '
          'and supabase/security_hardening.sql in the Supabase SQL editor.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save expense.');
    }
  }

  @override
  Future<ExpenseModel> updateExpense(Expense expense) async {
    final id = expense.id.trim();
    if (id.isEmpty) {
      throw const ServerException('Expense id is required.');
    }

    final existing = await _client
        .from(_table)
        .select(_selectWithClient)
        .eq('id', id)
        .maybeSingle();
    if (existing == null) {
      throw const ServerException('Expense not found.');
    }
    final current = ExpenseModel.fromJson(existing);
    if (current.approvalStatus != ExpenseApprovalStatus.pending) {
      throw const ServerException('Only pending expenses can be edited.');
    }

    final user = _authSession?.user;
    final uid = _client.auth.currentUser?.id ?? user?.id;
    final isStaff = AppAccess.isStaff(user);
    final isCreator =
        uid != null && current.createdBy != null && current.createdBy == uid;
    if (!isStaff && !isCreator) {
      throw const ServerException(
        'Only the creator or staff can edit this expense.',
      );
    }

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
    if (category.isEmpty) {
      throw const ServerException('Select a category.');
    }

    final clientId = expense.isCompanyExpense ? null : expense.clientId?.trim();
    final expenseDate = expense.expenseDate ?? current.expenseDate;

    String? ymd(DateTime? d) {
      if (d == null) return null;
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    final payload = <String, dynamic>{
      'made_for': madeFor,
      'amount': expense.amount,
      'paid_from': paidFrom,
      'category': category,
      'client_id': clientId,
      'expense_date': ymd(expenseDate),
      if (expense.receiptPath != null) 'receipt_path': expense.receiptPath,
      if (expense.receiptName != null) 'receipt_name': expense.receiptName,
    };

    try {
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('id', id)
          .select(_selectWithClient)
          .single();
      return ExpenseModel.fromJson(row);
    } on PostgrestException catch (e) {
      _throwCategoryConstraint(e);
      if (e.message.contains('expense_date') ||
          e.message.contains('receipt_')) {
        throw const ServerException(
          'Expense receipt/date columns are missing. Run '
          'supabase/ops_completeness_pack.sql in the Supabase SQL editor.',
        );
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update expense.');
    }
  }

  @override
  Future<ExpenseModel> uploadReceipt({
    required String expenseId,
    required String fileName,
    required Uint8List fileBytes,
    String mimeType = 'application/octet-stream',
  }) async {
    final id = expenseId.trim();
    if (id.isEmpty) {
      throw const ServerException('Expense id is required.');
    }
    final safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
    if (safeName.isEmpty || fileBytes.isEmpty) {
      throw const ServerException('Choose a receipt file.');
    }

    final path =
        'expenses/$id/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final resolvedMime = mimeType.trim().isEmpty
        ? 'application/octet-stream'
        : mimeType.trim();

    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: resolvedMime, upsert: true),
          );
      try {
        final row = await _client
            .from(_table)
            .update({'receipt_path': path, 'receipt_name': safeName})
            .eq('id', id)
            .select(_selectWithClient)
            .single();
        return ExpenseModel.fromJson(row);
      } on PostgrestException catch (e) {
        try {
          await _client.storage.from(_bucket).remove([path]);
        } catch (_) {}
        throw ServerException(e.message);
      }
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to upload receipt.');
    }
  }

  @override
  Future<String> receiptDownloadUrl(String receiptPath) async {
    final path = receiptPath.trim();
    if (path.isEmpty) {
      throw const ServerException('No receipt is attached.');
    }
    final url = await AppStorageUrls.resolveUrl(
      _client,
      bucket: _bucket,
      path: path,
    );
    if (url == null || url.isEmpty) {
      throw const ServerException('Could not open receipt.');
    }
    return url;
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
