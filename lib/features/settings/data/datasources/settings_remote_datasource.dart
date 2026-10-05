import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/app_access.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/settings_entities.dart';

abstract class SettingsRemoteDataSource {
  Future<CompanyDetails> getCompanyDetails({String name = 'sayge'});

  Future<CompanyDetails> updateCompanyDetails(CompanyDetails details);

  Future<CompanyDetails> updateCompanyLogo({
    required String companyId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });

  Future<List<AppRole>> getRoles();

  Future<List<ActivityLogEntry>> getActivityLog({int limit = 200});
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  SettingsRemoteDataSourceImpl({
    SupabaseClient? client,
    this._authSession,
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final AuthSession? _authSession;

  static const _brandLogosBucket = 'brand-logos';
  static const _documentsBucket = 'documents';
  static const _companyTable = 'company_details';

  String? logoPublicUrl(String? path) {
    final trimmed = path?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final bucket =
        trimmed.startsWith('documents/') ? _documentsBucket : _brandLogosBucket;
    try {
      return _client.storage.from(bucket).getPublicUrl(trimmed);
    } catch (_) {
      return null;
    }
  }

  CompanyDetails _withLogoUrl(CompanyDetails details) {
    final url = logoPublicUrl(details.logoPath);
    if (url == null && (details.logoUrl?.isNotEmpty != true)) {
      return details;
    }
    return CompanyDetails(
      id: details.id,
      name: details.name,
      displayName: details.displayName,
      address: details.address,
      gstin: details.gstin,
      pan: details.pan,
      sacCode: details.sacCode,
      telephone: details.telephone,
      email: details.email,
      bankName: details.bankName,
      bankAccountNo: details.bankAccountNo,
      bankBranch: details.bankBranch,
      bankIfsc: details.bankIfsc,
      logoPath: details.logoPath,
      logoUrl: url ?? details.logoUrl,
    );
  }

  @override
  Future<CompanyDetails> getCompanyDetails({String name = 'sayge'}) async {
    try {
      final row = await _client
          .from('company_details')
          .select()
          .eq('name', name)
          .maybeSingle();
      if (row == null) {
        throw const ServerException('Company details not found for sayge.');
      }
      return _withLogoUrl(_companyFromJson(row));
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to load company details.');
    }
  }

  @override
  Future<CompanyDetails> updateCompanyDetails(CompanyDetails details) async {
    try {
      final row = await _client
          .from('company_details')
          .update({
            'display_name': details.displayName.trim(),
            'address': details.address.trim(),
            'gstin': details.gstin.trim(),
            'pan': details.pan.trim(),
            'sac_code': details.sacCode.trim(),
            'telephone': details.telephone.trim(),
            'email': details.email.trim(),
            'bank_name': details.bankName.trim(),
            'bank_account_no': details.bankAccountNo.trim(),
            'bank_branch': details.bankBranch.trim(),
            'bank_ifsc': details.bankIfsc.trim(),
          })
          .eq('id', details.id)
          .select()
          .single();
      return _withLogoUrl(_companyFromJson(row));
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save company details.');
    }
  }

  @override
  Future<CompanyDetails> updateCompanyLogo({
    required String companyId,
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    if (!AppAccess.isStaff(_authSession?.user)) {
      throw const ServerException(
        'Only owners and admins can update company details.',
      );
    }
    if (bytes.isEmpty) {
      throw const ServerException('Choose an image to upload.');
    }
    final id = companyId.trim();
    if (id.isEmpty) {
      throw const ServerException('Company id is required.');
    }

    var safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
    if (safeName.isEmpty) safeName = 'logo.jpg';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'jpg';
    final path =
        'company/$id/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType =
        mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim();

    try {
      final existing = await _client
          .from(_companyTable)
          .select('logo_path')
          .eq('id', id)
          .maybeSingle();
      final previous = (existing?['logo_path'] ?? '').toString().trim();

      await _client.storage.from(_brandLogosBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      final row = await _client
          .from(_companyTable)
          .update({'logo_path': path})
          .eq('id', id)
          .select()
          .single();

      if (previous.isNotEmpty &&
          previous != path &&
          !previous.startsWith('documents/')) {
        try {
          await _client.storage.from(_brandLogosBucket).remove([previous]);
        } catch (_) {}
      }

      return _withLogoUrl(_companyFromJson(row));
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to update company logo.');
    }
  }

  @override
  Future<List<AppRole>> getRoles() async {
    try {
      final rows = await _client
          .from('roles')
          .select()
          .order('sort_order');
      return (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        return AppRole(
          id: (map['id'] ?? '').toString(),
          code: (map['code'] ?? '').toString(),
          label: (map['label'] ?? '').toString(),
          description: (map['description'] ?? '').toString(),
          sortOrder: int.tryParse('${map['sort_order'] ?? 0}') ?? 0,
          isActive: map['is_active'] == true || map['is_active'] == 'true',
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load roles.');
    }
  }

  @override
  Future<List<ActivityLogEntry>> getActivityLog({int limit = 200}) async {
    try {
      final rows = await _client
          .from('activity_log')
          .select()
          .order('occurred_at', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>).map((row) {
        final map = row as Map<String, dynamic>;
        final action = (map['action'] ?? '').toString();
        final table = (map['table_name'] ?? '').toString();
        final recordId = (map['record_id'] ?? '').toString();
        return ActivityLogEntry(
          id: int.tryParse('${map['id'] ?? 0}') ?? 0,
          occurredAt: DateTime.tryParse('${map['occurred_at']}') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          tableName: table,
          recordId: recordId,
          action: action,
          actorEmail: (map['actor_email'] as String?)?.trim(),
          summary: _summary(action: action, table: table, recordId: recordId),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException('Failed to load activity ledger.');
    }
  }

  CompanyDetails _companyFromJson(Map<String, dynamic> map) {
    String read(String key) => (map[key] ?? '').toString();
    return CompanyDetails(
      id: read('id'),
      name: read('name'),
      displayName: read('display_name'),
      address: read('address'),
      gstin: read('gstin'),
      pan: read('pan'),
      sacCode: read('sac_code'),
      telephone: read('telephone'),
      email: read('email'),
      bankName: read('bank_name'),
      bankAccountNo: read('bank_account_no'),
      bankBranch: read('bank_branch'),
      bankIfsc: read('bank_ifsc'),
      logoPath: read('logo_path'),
    );
  }

  String _summary({
    required String action,
    required String table,
    required String recordId,
  }) {
    final verb = switch (action.toUpperCase()) {
      'INSERT' => 'Created',
      'UPDATE' => 'Updated',
      'DELETE' => 'Deleted',
      _ => action,
    };
    final label = table.replaceAll('_', ' ');
    if (recordId.isEmpty) return '$verb $label';
    return '$verb $label · $recordId';
  }
}
