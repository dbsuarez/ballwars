import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('M3 lock triggers precede existing count-limit triggers', () {
    final sql = File('supabase/migrations/027_serialize_group_limits.sql')
        .readAsStringSync();
    for (final name in [
      'a_lock_ball_group_limit',
      'a_lock_group_ball_limit',
      'a_lock_saved_group_limit',
    ]) {
      expect(sql, contains('CREATE TRIGGER $name'));
    }
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains("lock_kind := 'balls-per-group'"));
    expect(sql, contains("lock_kind := 'saved-per-owner'"));
  });
}
