import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('H1 replay quota is shared across anonymous accounts and serialized', () {
    final sql = File('supabase/migrations/022_replay_global_budget.sql')
        .readAsStringSync();
    expect(sql, contains('BEFORE INSERT ON public.replays'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('daily_count >= max_daily_replays'));
    expect(sql, contains('daily_bytes + incoming_bytes > max_daily_bytes'));
    expect(sql, contains('octet_length'));
    expect(sql, contains('created_at >= day_start'));
    // The shared budget must not filter rows by creator or auth.uid().
    expect(sql, isNot(contains('r.creator =')));
    expect(sql, isNot(contains('auth.uid()')));
  });
}
