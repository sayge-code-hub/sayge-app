import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads Supabase credentials from the bundled `.env` asset.
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

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_REF') &&
      supabaseAnonKey != 'YOUR_ANON_KEY';
}
