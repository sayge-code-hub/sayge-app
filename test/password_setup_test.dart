import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/auth/password_setup.dart';

void main() {
  group('PasswordSetup.metadataRequiresSetup', () {
    test('true for invite flags', () {
      expect(
        PasswordSetup.metadataRequiresSetup({'must_set_password': true}),
        isTrue,
      );
      expect(
        PasswordSetup.metadataRequiresSetup({'must_set_password': 'true'}),
        isTrue,
      );
      expect(
        PasswordSetup.metadataRequiresSetup({'must_set_password': 1}),
        isTrue,
      );
    });

    test('false when cleared after password set', () {
      expect(
        PasswordSetup.metadataRequiresSetup({'must_set_password': false}),
        isFalse,
      );
      expect(
        PasswordSetup.metadataRequiresSetup({'must_set_password': 'false'}),
        isFalse,
      );
      expect(PasswordSetup.metadataRequiresSetup(null), isFalse);
      expect(PasswordSetup.metadataRequiresSetup({}), isFalse);
    });
  });
}
