import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/exceptions.dart';
import '../models/employee_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getEmployees();

  Future<EmployeeModel> addEmployee(EmployeeModel employee);

  Future<EmployeeModel> updateEmployee(EmployeeModel employee);

  /// Marks employee inactive with [dateOfExit] and disables linked login accounts.
  Future<EmployeeModel> exitEmployee({
    required String employeeId,
    required DateTime dateOfExit,
  });
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  EmployeeRemoteDataSourceImpl({
    SupabaseClient? client,
    this._authSession,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AuthSession? _authSession;

  static const _table = 'employees';
  static const _selectWithClient = '*, clients(id, name)';

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      var query = _client.from(_table).select(_selectWithClient);

      final user = _authSession?.user;
      if (AppAccess.isEmployeeOnly(user)) {
        final id = user!.employeeId?.trim();
        if (id == null || id.isEmpty) {
          return const [];
        }
        query = query.eq('employee_id', id);
      }

      final rows = await query.order('employee_name', ascending: true);
      return (rows as List<dynamic>)
          .map((row) => EmployeeModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load employees from Supabase.');
    }
  }

  @override
  Future<EmployeeModel> addEmployee(EmployeeModel employee) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException('Only owners and admins can add employees.');
    }
    try {
      final row = await _client
          .from(_table)
          .insert(employee.toJson())
          .select(_selectWithClient)
          .single();
      return EmployeeModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const ServerException('Employee ID already exists.');
      }
      if (e.code == '23503') {
        throw const ServerException('Selected client does not exist.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to add employee.');
    }
  }

  @override
  Future<EmployeeModel> updateEmployee(EmployeeModel employee) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can update employees.',
      );
    }
    try {
      final row = await _client
          .from(_table)
          .update(employee.toJson())
          .eq('employee_id', employee.employeeId)
          .select(_selectWithClient)
          .single();
      return EmployeeModel.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const ServerException('Selected client does not exist.');
      }
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to update employee.');
    }
  }

  @override
  Future<EmployeeModel> exitEmployee({
    required String employeeId,
    required DateTime dateOfExit,
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can exit employees.',
      );
    }
    try {
      final exitDay = dateOfExit.toIso8601String().split('T').first;
      final row = await _client
          .from(_table)
          .update({
            'is_active': false,
            'date_of_exit': exitDay,
          })
          .eq('employee_id', employeeId)
          .select(_selectWithClient)
          .single();

      await _client
          .from('users')
          .update({'is_active': false})
          .eq('employee_id', employeeId);

      return EmployeeModel.fromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to exit employee.');
    }
  }
}
