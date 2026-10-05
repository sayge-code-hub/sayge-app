import 'package:flutter/foundation.dart';
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

  /// Uploads a new profile picture for the current user and returns the
  /// updated profile (with resolved [UserModel.avatarUrl]).
  Future<UserModel> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  });

  String? avatarPublicUrl(String? avatarPath);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _bucket = 'user-avatars';

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
      // Local scope clears the browser/session storage for this client.
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      try {
        await _client.auth.signOut();
      } catch (_) {
        // Local clear still proceeds even if remote sign-out fails.
      }
    }
  }

  @override
  String? avatarPublicUrl(String? avatarPath) {
    final path = avatarPath?.trim() ?? '';
    if (path.isEmpty) return null;
    try {
      return _client.storage.from(_bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/jpeg',
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw const core.AuthException('Sign in to update your profile picture.');
    }
    if (bytes.isEmpty) {
      throw const core.ServerException('Choose an image to upload.');
    }

    var safeName = fileName.trim().replaceAll(RegExp(r'[^\w.\-]+'), '_');
    if (safeName.isEmpty) safeName = 'avatar.jpg';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'jpg';
    final path =
        '${authUser.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final contentType = mimeType.trim().isEmpty ? 'image/jpeg' : mimeType.trim();

    try {
      final existing = await _client
          .from('users')
          .select('avatar_path')
          .eq('id', authUser.id)
          .maybeSingle();
      final previous = (existing?['avatar_path'] ?? '').toString().trim();

      await _client.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );
      await _client.from('users').update({'avatar_path': path}).eq('id', authUser.id);

      if (previous.isNotEmpty && previous != path) {
        try {
          await _client.storage.from(_bucket).remove([previous]);
        } catch (_) {}
      }
      return _fetchProfile(authUser.id);
    } on StorageException catch (e) {
      throw core.ServerException(e.message);
    } on PostgrestException catch (e) {
      throw core.ServerException(e.message);
    } on core.AuthException {
      rethrow;
    } on core.ServerException {
      rethrow;
    } catch (_) {
      throw const core.NetworkException('Failed to update profile picture.');
    }
  }

  Future<UserModel> _fetchProfile(String userId) async {
    final profile = await _client
        .from('users')
        .select(
          'id, email, full_name, role_id, employee_id, avatar_path, is_active, '
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

    final path = (profile['avatar_path'] ?? '').toString().trim();
    var avatarUrl = avatarPublicUrl(path.isEmpty ? null : path);

    // Linked employees without a personal avatar fall back to their HR photo.
    if ((avatarUrl == null || avatarUrl.isEmpty)) {
      final employeeId = (profile['employee_id'] ?? '').toString().trim();
      if (employeeId.isNotEmpty) {
        try {
          final employee = await _client
              .from('employees')
              .select('photo_path')
              .eq('employee_id', employeeId)
              .maybeSingle();
          final photoPath = (employee?['photo_path'] ?? '').toString().trim();
          if (photoPath.isNotEmpty) {
            final bucket = photoPath.startsWith('documents/')
                ? 'documents'
                : 'employee-avatars';
            avatarUrl = _client.storage.from(bucket).getPublicUrl(photoPath);
          }
        } catch (_) {}
      }
    }

    return UserModel.fromProfileRow(
      profile,
      avatarUrl: avatarUrl,
    );
  }
}
