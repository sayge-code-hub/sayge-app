import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/storage/app_storage_urls.dart';

void main() {
  group('AppStorageUrls.bucketForPath', () {
    test('routes documents prefix to private documents bucket', () {
      expect(
        AppStorageUrls.bucketForPath(
          'documents/emp/photo.jpg',
          publicDefault: 'employee-avatars',
        ),
        'documents',
      );
    });

    test('routes employee-pos prefix to private bucket', () {
      expect(
        AppStorageUrls.bucketForPath(
          'employee-pos/po.pdf',
          publicDefault: 'brand-logos',
        ),
        'employee-pos',
      );
    });

    test('falls back to public default for avatar paths', () {
      expect(
        AppStorageUrls.bucketForPath(
          'emp_1/avatar.jpg',
          publicDefault: 'employee-avatars',
        ),
        'employee-avatars',
      );
    });
  });

  group('AppStorageUrls.privateBuckets', () {
    test('documents and employee-pos are private', () {
      expect(AppStorageUrls.privateBuckets.contains('documents'), isTrue);
      expect(AppStorageUrls.privateBuckets.contains('employee-pos'), isTrue);
      expect(AppStorageUrls.privateBuckets.contains('brand-logos'), isFalse);
    });
  });
}
