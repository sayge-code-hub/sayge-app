import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/expense_category.dart';

abstract class ExpenseCategoryRemoteDataSource {
  Future<List<ExpenseCategory>> listCategories();

  Future<void> addCategory(String name);

  Future<void> renameCategory({required String id, required String name});

  Future<void> deleteCategory(String id);
}

class ExpenseCategoryRemoteDataSourceImpl
    implements ExpenseCategoryRemoteDataSource {
  ExpenseCategoryRemoteDataSourceImpl({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'expense_categories';
  static const setupMessage =
      'Categories are not set up yet. Run supabase/expense_categories.sql '
      'in the Supabase SQL editor, then try again.';

  @override
  Future<List<ExpenseCategory>> listCategories() async {
    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('sort_order', ascending: true)
          .order('name', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => ExpenseCategory.fromJson(row as Map<String, dynamic>))
          .where((category) => category.name.trim().isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) {
        throw const ServerException(setupMessage);
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load categories.');
    }
  }

  @override
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ServerException('Enter a category name.');
    }
    final existing = await listCategories();
    if (_nameTaken(existing, trimmed)) {
      throw const ServerException('A category with that name already exists.');
    }
    final nextOrder = existing.isEmpty
        ? 0
        : existing
                  .map((category) => category.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    try {
      final inserted = await _client
          .from(_table)
          .insert({
            'id': 'cat_${DateTime.now().microsecondsSinceEpoch}',
            'name': trimmed,
            'sort_order': nextOrder,
          })
          .select()
          .maybeSingle();
      if (inserted == null) {
        throw const ServerException('Could not add that category.');
      }
    } on PostgrestException catch (e) {
      _throwWriteError(e);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to add category.');
    }
  }

  @override
  Future<void> renameCategory({
    required String id,
    required String name,
  }) async {
    final trimmed = name.trim();
    if (id.trim().isEmpty || trimmed.isEmpty) {
      throw const ServerException('Enter a category name.');
    }
    final existing = await listCategories();
    final current = _find(existing, id);
    if (current == null) {
      throw const ServerException('Category not found.');
    }
    if (current.name == trimmed) return;
    if (_nameTaken(existing, trimmed, exceptId: id)) {
      throw const ServerException('A category with that name already exists.');
    }

    try {
      await _client.from(_table).update({'name': trimmed}).eq('id', id);
    } on PostgrestException catch (e) {
      _throwWriteError(e);
    }

    try {
      await _client
          .from('expenses')
          .update({'category': trimmed})
          .eq('category', current.name);
    } on PostgrestException catch (e) {
      await _client.from(_table).update({'name': current.name}).eq('id', id);
      _throwExpenseConstraint(e);
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to rename category.');
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final existing = await listCategories();
    final current = _find(existing, id);
    if (current == null) {
      throw const ServerException('Category not found.');
    }

    try {
      final used = await _client
          .from('expenses')
          .select('id')
          .eq('category', current.name)
          .limit(1);
      if (used.isNotEmpty) {
        throw const ServerException(
          'This category is used on existing expenses. Rename it instead of deleting it.',
        );
      }
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (_isMissingTable(e)) {
        throw const ServerException(setupMessage);
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to delete category.');
    }
  }

  ExpenseCategory? _find(List<ExpenseCategory> categories, String id) {
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  bool _nameTaken(
    List<ExpenseCategory> categories,
    String name, {
    String? exceptId,
  }) {
    final key = name.trim().toLowerCase();
    return categories.any(
      (category) =>
          category.id != exceptId && category.name.trim().toLowerCase() == key,
    );
  }

  bool _isMissingTable(PostgrestException e) {
    final code = (e.code ?? '').toUpperCase();
    if (code == '42P01' || code == 'PGRST205') return true;
    final message = e.message.toLowerCase();
    return message.contains('expense_categories') &&
        (message.contains('does not exist') ||
            message.contains('schema cache') ||
            message.contains('could not find'));
  }

  Never _throwWriteError(PostgrestException e) {
    if (_isMissingTable(e)) {
      throw const ServerException(setupMessage);
    }
    if ((e.code ?? '') == '23505') {
      throw const ServerException('A category with that name already exists.');
    }
    throw ServerException(e.message);
  }

  void _throwExpenseConstraint(PostgrestException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == '23514' && message.contains('category')) {
      throw const ServerException(setupMessage);
    }
  }
}
