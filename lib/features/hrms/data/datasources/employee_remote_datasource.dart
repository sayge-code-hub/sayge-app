import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../models/employee_model.dart';

abstract class EmployeeRemoteDataSource {
  Future<List<EmployeeModel>> getEmployees();

  Future<EmployeeModel> addEmployee(EmployeeModel employee);

  Future<EmployeeModel> updateEmployee(EmployeeModel employee);
}

class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  EmployeeRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'employees';
  static const _selectWithClient = '*, clients(id, name)';

  @override
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      final rows = await _client
          .from(_table)
          .select(_selectWithClient)
          .order('employee_name', ascending: true);
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
}
