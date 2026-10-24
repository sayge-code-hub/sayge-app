import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/app_storage_urls.dart';
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

  /// Reactivates an exited employee and re-enables linked login accounts.
  Future<EmployeeModel> rehireEmployee({
    required String employeeId,
    DateTime? dateOfJoining,
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
    final bucket = AppStorageUrls.bucketForPath(
      trimmed,
      publicDefault: _avatarsBucket,
    );
    return AppStorageUrls.publicUrl(
      _client,
      bucket: bucket,
      path: trimmed,
    );
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
      final models = (rows as List<dynamic>)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();

      // Billing / PO rate is owner-staff only — never expose to the employee.
      if (AppAccess.isEmployeeOnly(user)) {
        return [
          for (final model in models)
            EmployeeModel.fromEntity(model.copyWith(monthlyRate: 0)),
        ];
      }
      return models;
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
    final user = _authSession?.user;
    final isStaff = AppAccess.isStaff(user);
    final selfId = user?.employeeId?.trim() ?? '';
    final targetId = employee.employeeId.trim();
    final isSelf = selfId.isNotEmpty && selfId == targetId;

    if (!isStaff && !isSelf) {
      throw const ServerException(
        'Only owners, admins, or the employee themselves can update this profile.',
      );
    }

    try {
      final Map<String, dynamic> payload;
      if (isStaff) {
        payload = employee.toJson();
      } else {
        // Self-service: contact fields only (RLS trigger enforces the same).
        payload = {
          'contact_no': employee.contactNo,
          'personal_email': employee.personalEmail,
          'residential_address': employee.residentialAddress,
          'alternate_contact': employee.alternateContact,
        };
      }
      final row = await _client
          .from(_table)
          .update(payload)
          .eq('employee_id', employee.employeeId)
          .select(_selectWithClient)
          .single();
      return _fromRow(row);
    } on PostgrestException catch (e) {
      if (e.code == '23503') {
        throw const ServerException('Selected client does not exist.');
      }
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
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
  Future<EmployeeModel> rehireEmployee({
    required String employeeId,
    DateTime? dateOfJoining,
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can rehire employees.',
      );
    }
    try {
      final patch = <String, dynamic>{
        'is_active': true,
        'date_of_exit': null,
      };
      if (dateOfJoining != null) {
        patch['date_of_joining'] =
            dateOfJoining.toIso8601String().split('T').first;
      }

      final row = await _client
          .from(_table)
          .update(patch)
          .eq('employee_id', employeeId)
          .select(_selectWithClient)
          .single();

      await _client
          .from('users')
          .update({'is_active': true})
          .eq('employee_id', employeeId);

      return _fromRow(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to rehire employee.');
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
      // Copy into the public avatars bucket — never point photo_path at private
      // `documents/` objects (getPublicUrl would fail / leak if misconfigured).
      final sourceBucket = AppStorageUrls.bucketForPath(
        path,
        publicDefault: _documentsBucket,
      );
      final bytes = await _client.storage.from(sourceBucket).download(path);
      final fileName = path.split('/').last;
      final ext = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
          : 'jpg';
      final mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      return await updateEmployeePhoto(
        employeeId: employeeId,
        bytes: bytes,
        fileName: fileName.isEmpty ? 'avatar.$ext' : fileName,
        mimeType: mime,
      );
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to set employee photo.');
    }
  }
}
