import 'package:flutter/foundation.dart';
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

  Future<EmployeeModel> updateEmployeePhoto({
    required String employeeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });

  Future<EmployeeModel> setEmployeePhotoFromDocument({
    required String employeeId,
    required String storagePath,
  });

  String? photoPublicUrl(String? path);
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
  static const _avatarsBucket = 'employee-avatars';
  static const _documentsBucket = 'documents';

  @override
  String? photoPublicUrl(String? path) {
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final bucket =
        trimmed.startsWith('documents/') ? _documentsBucket : _avatarsBucket;
    try {
      return _client.storage.from(bucket).getPublicUrl(trimmed);
    } catch (_) {
      return null;
    }
  }

  EmployeeModel _fromRow(Map<String, dynamic> row) {
    final model = EmployeeModel.fromJson(row);
    final url = photoPublicUrl(model.photoPath);
    if (url == null && (model.photoUrl?.isNotEmpty != true)) {
      return model;
    }
    return EmployeeModel.fromEntity(
      model.copyWith(photoUrl: url ?? model.photoUrl),
    );
  }

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
          .map((row) => _fromRow(row as Map<String, dynamic>))
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
      return _fromRow(row);
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
      return _fromRow(row);
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

      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to exit employee.');
    }
  }

  @override
  Future<EmployeeModel> updateEmployeePhoto({
    required String employeeId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can update employees.',
      );
    }
    if (bytes.isEmpty) {
      throw const ServerException('Choose an image to upload.');
    }

    var safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
    if (safeName.isEmpty) safeName = 'avatar.jpg';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'jpg';
    final path =
        '$employeeId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType =
        mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim();

    try {
      final existing = await _client
          .from(_table)
          .select('photo_path')
          .eq('employee_id', employeeId)
          .maybeSingle();
      final previous = (existing?['photo_path'] ?? '').toString().trim();

      await _client.storage.from(_avatarsBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final row = await _client
          .from(_table)
          .update({'photo_path': path})
          .eq('employee_id', employeeId)
          .select(_selectWithClient)
          .single();

      if (previous.isNotEmpty &&
          previous != path &&
          !previous.startsWith('documents/')) {
        try {
          await _client.storage.from(_avatarsBucket).remove([previous]);
        } catch (_) {}
      }

      return _fromRow(row);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update employee photo.');
    }
  }

  @override
  Future<EmployeeModel> setEmployeePhotoFromDocument({
    required String employeeId,
    required String storagePath,
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can update employees.',
      );
    }
    final path = storagePath.trim();
    if (path.isEmpty) {
      throw const ServerException('Document path is missing.');
    }
    try {
      final row = await _client
          .from(_table)
          .update({'photo_path': path})
          .eq('employee_id', employeeId)
          .select(_selectWithClient)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to set employee photo.');
    }
  }
}
