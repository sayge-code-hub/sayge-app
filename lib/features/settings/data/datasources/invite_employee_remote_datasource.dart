import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/pending_invite.dart';

class InviteEmployeeRemoteDataSource {
  InviteEmployeeRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> invite({
    required String email,
    String fullName = '',
    String roleId = 'role_employee',
    String employeeId = '',
    String cafeId = '',
  }) async {
    await _invoke(
      body: {
        'action': 'invite',
        'email': email.trim().toLowerCase(),
        'fullName': fullName.trim(),
        'roleId': roleId.trim(),
        if (employeeId.trim().isNotEmpty) 'employeeId': employeeId.trim(),
        if (cafeId.trim().isNotEmpty) 'cafeId': cafeId.trim(),
        if (AppConfig.inviteRedirectUrl.isNotEmpty)
          'redirectTo': AppConfig.inviteRedirectUrl,
      },
    );
  }

  Future<List<PendingInvite>> listPending() async {
    final data = await _invoke(body: {'action': 'list'});
    final raw = data is Map ? data['invites'] : null;
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          PendingInvite(
            id: (item['id'] ?? '').toString(),
            email: (item['email'] ?? '').toString(),
            fullName: (item['fullName'] ?? item['full_name'] ?? '').toString(),
            invitedAt: _parseDate(item['invitedAt'] ?? item['invited_at']),
          ),
    ];
  }

  Future<void> resend(String email) async {
    await _invoke(
      body: {
        'action': 'resend',
        'email': email.trim().toLowerCase(),
        if (AppConfig.inviteRedirectUrl.isNotEmpty)
          'redirectTo': AppConfig.inviteRedirectUrl,
      },
    );
  }

  Future<void> revoke({String? email, String? userId}) async {
    final trimmedEmail = email?.trim().toLowerCase() ?? '';
    final trimmedId = userId?.trim() ?? '';
    if (trimmedEmail.isEmpty && trimmedId.isEmpty) {
      throw const ServerException('email or userId is required');
    }
    await _invoke(
      body: {
        'action': 'revoke',
        if (trimmedEmail.isNotEmpty) 'email': trimmedEmail,
        if (trimmedId.isNotEmpty) 'userId': trimmedId,
      },
    );
  }

  Future<dynamic> _invoke({required Map<String, dynamic> body}) async {
    try {
      final response = await _client.functions.invoke(
        'invite-employee',
        body: body,
      );

      final data = response.data;
      if (response.status >= 400) {
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Invite request failed (${response.status}).';
        throw ServerException(message);
      }
      if (data is Map && data['error'] != null) {
        throw ServerException(data['error'].toString());
      }
      return data;
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'Invite request failed.');
      throw ServerException(message);
    } on ServerException {
      rethrow;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
