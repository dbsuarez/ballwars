import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M8 fallback only handles connectivity errors', () {
    final source = File('lib/features/custom_groups/data/custom_group_repository.dart').readAsStringSync();
    final start = source.indexOf('static Future<List<Map<String, dynamic>>> _offline(');
    final end = source.indexOf('  @override', start);
    final method = source.substring(start, end);
    expect(method, contains('on TimeoutException'));
    expect(method, contains('on SocketException'));
    expect(method, isNot(contains('catch (_)')));
  });
}
