import 'package:supabase_flutter/supabase_flutter.dart';

/// Helpers for Storage URLs. Private buckets must never use [getPublicUrl].
abstract final class AppStorageUrls {
  static const privateBuckets = {'documents', 'employee-pos'};

  /// Picks bucket from a stored path prefix; otherwise [publicDefault].
  static String bucketForPath(
    String path, {
    required String publicDefault,
  }) {
    final trimmed = path.trim();
    if (trimmed.startsWith('documents/')) return 'documents';
    if (trimmed.startsWith('employee-pos/')) return 'employee-pos';
    return publicDefault;
  }

  /// Public object URL, or null for private buckets / failures.
  static String? publicUrl(
    SupabaseClient client, {
    required String bucket,
    required String path,
  }) {
    final b = bucket.trim();
    final p = path.trim();
    if (p.isEmpty || privateBuckets.contains(b)) return null;
    try {
      return client.storage.from(b).getPublicUrl(p);
    } catch (_) {
      return null;
    }
  }

  /// Signed URL for private buckets; public URL otherwise.
  static Future<String?> resolveUrl(
    SupabaseClient client, {
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    final b = bucket.trim();
    final p = path.trim();
    if (p.isEmpty) return null;
    try {
      if (privateBuckets.contains(b)) {
        return await client.storage.from(b).createSignedUrl(p, expiresIn);
      }
      return client.storage.from(b).getPublicUrl(p);
    } catch (_) {
      return null;
    }
  }
}
