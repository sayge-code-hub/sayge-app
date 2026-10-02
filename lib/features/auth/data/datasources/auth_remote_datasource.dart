import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as core;
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login({
    required String email,
    required String password,
  });

  /// Returns the profile for the current Supabase session, if any.
  Future<UserModel?> restoreSession();

  Future<void> signOut();
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

      return _fetchProfile(authUser.id);
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

  @override
  Future<UserModel?> restoreSession() async {
    final session = _client.auth.currentSession;
    final authUser = session?.user ?? _client.auth.currentUser;
    if (session == null || authUser == null) return null;
    try {
      return await _fetchProfile(authUser.id);
    } on core.AuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Local clear still proceeds even if remote sign-out fails.
    }
  }

  Future<UserModel> _fetchProfile(String userId) async {
    final profile = await _client
        .from('users')
        .select(
          'id, email, full_name, role_id, employee_id, is_active, '
          'roles(code, label)',
        )
        .eq('id', userId)
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
  }
}
