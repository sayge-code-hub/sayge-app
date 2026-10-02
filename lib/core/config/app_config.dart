import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads public client config from the bundled `assets/config/app.env` asset.
abstract final class AppConfig {
  static String get supabaseUrl {
    try {
      return dotenv.env['SUPABASE_URL']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String get supabaseAnonKey {
    try {
      return dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Public web origin for Auth redirects (invite / set-password).
  /// Prefer APP_PUBLIC_URL in app.env; falls back to current origin on web.
  static String get appPublicUrl {
    try {
      final fromEnv = dotenv.env['APP_PUBLIC_URL']?.trim() ?? '';
      if (fromEnv.isNotEmpty) {
        return fromEnv.replaceAll(RegExp(r'/+$'), '');
      }
    } catch (_) {}
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return '';
  }

  static String get inviteRedirectUrl {
    final base = appPublicUrl;
    if (base.isEmpty) return '';
    return '$base/set-password';
  }

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_REF') &&
      supabaseAnonKey != 'YOUR_ANON_KEY';
}
