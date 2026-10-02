import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';

class InviteEmployeeRemoteDataSource {
  InviteEmployeeRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> invite({
    required String email,
    String fullName = '',
    String roleId = 'role_employee',
    String employeeId = '',
  }) async {
    try {
      final response = await _client.functions.invoke(
        'invite-employee',
        body: {
          'email': email.trim().toLowerCase(),
          'fullName': fullName.trim(),
          'roleId': roleId.trim(),
          if (employeeId.trim().isNotEmpty) 'employeeId': employeeId.trim(),
          if (AppConfig.inviteRedirectUrl.isNotEmpty)
            'redirectTo': AppConfig.inviteRedirectUrl,
        },
      );

      final data = response.data;
      if (response.status >= 400) {
        final message = data is Map && data['error'] != null
            ? data['error'].toString()
            : 'Invite failed (${response.status}).';
        throw ServerException(message);
      }
      if (data is Map && data['error'] != null) {
        throw ServerException(data['error'].toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : (e.reasonPhrase ?? 'Invite failed.');
      throw ServerException(message);
    } on ServerException {
      rethrow;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw NetworkException(e.toString());
    }
  }
}
