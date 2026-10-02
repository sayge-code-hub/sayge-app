import 'package:flutter_test/flutter_test.dart';
import 'package:sayge_app/core/config/app_config.dart';

void main() {
  test('AppConfig.hasSupabase is false for placeholder credentials', () {
    // dotenv is not loaded in this unit test; env map is empty.
    expect(AppConfig.hasSupabase, isFalse);
  });
}
