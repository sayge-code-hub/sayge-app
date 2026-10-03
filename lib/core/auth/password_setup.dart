import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the current auth user still must choose a password (invite flow).
abstract final class PasswordSetup {
  static const metaKey = 'must_set_password';

  static bool metadataRequiresSetup(Map<String, dynamic>? meta) {
    if (meta == null) return false;
    final value = meta[metaKey];
    return value == true || value == 'true' || value == 1 || value == '1';
  }

  /// Invite / recovery links put `type=invite` (or recovery) in the URL.
  static bool urlIndicatesInvite() {
    if (!kIsWeb) return false;
    final base = Uri.base;
    final type = base.queryParameters['type']?.toLowerCase();
    if (type == 'invite' || type == 'recovery') return true;
    final frag = base.fragment.toLowerCase();
    if (frag.contains('type=invite') || frag.contains('type=recovery')) {
      return true;
    }
    return false;
  }

  static bool currentUserRequiresSetup() {
    if (urlIndicatesInvite()) return true;
    final user = Supabase.instance.client.auth.currentUser;
    return metadataRequiresSetup(user?.userMetadata);
  }
}
