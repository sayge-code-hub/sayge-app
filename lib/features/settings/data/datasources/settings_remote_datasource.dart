import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/settings_entities.dart';

abstract class SettingsRemoteDataSource {
  Future<CompanyDetails> getCompanyDetails({String name = 'sayge'});

  Future<CompanyDetails> updateCompanyDetails(CompanyDetails details);

  Future<List<AppRole>> getRoles();

  Future<List<ActivityLogEntry>> getActivityLog({int limit = 200});
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  SettingsRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
      return _companyFromJson(row);
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
      return _companyFromJson(row);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw const NetworkException('Failed to save company details.');
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
