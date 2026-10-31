import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M9 web does not persist admin refresh tokens', () {
    final source = File('lib/features/settings/data/app_settings_repository.dart').readAsStringSync();
    expect(source, contains("_rememberSession = rememberMe && !kIsWeb;"));
    expect(source, contains("_rememberSession = !kIsWeb &&"));
  });
}
