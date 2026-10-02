import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as core;
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null || authUser.email == null) {
        throw const core.AuthException('Invalid email or password.');
      }

      final profile = await _client
          .from('users')
          .select(
            'id, email, full_name, role_id, employee_id, is_active, '
            'roles(code, label)',
          )
          .eq('id', authUser.id)
          .maybeSingle();

      if (profile == null) {
        throw const core.AuthException(
          'No user profile found. Ask an admin to provision your account.',
        );
      }

      if (profile['is_active'] == false) {
        throw const core.AuthException('This account is inactive.');
      }

      return UserModel.fromProfileRow(profile);
    } on core.AuthException {
      rethrow;
    } on AuthException catch (e) {
      throw core.AuthException(e.message);
    } on PostgrestException catch (e) {
      throw core.AuthException(e.message);
    } catch (_) {
      throw const core.AuthException(
        'Unable to sign in. Check your credentials.',
      );
    }
  }
}
