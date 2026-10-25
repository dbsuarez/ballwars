import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ballwars/features/replay_export/data/short_link_repository.dart';

void main() {
  test('unsupported match options fall back to full links before contacting server', () async {
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    addTearDown(client.dispose);
    final repository = SupabaseShortLinkRepository(client);
    for (final option in ['mayhem', 'duration', 'endless', 'dw', 'shrink']) {
      await expectLater(repository.create({
        'seed': '42', 'balls': 'p.a,p.b', option: '1',
      }), throwsStateError);
    }
  });
}
