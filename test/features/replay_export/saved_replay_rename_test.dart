import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';

void main() {
  test('default name includes time and safe contestant names', () async {
    OfflineStore.instance = MemoryOfflineStore();
    final uri = Uri.parse('https://example.com/?seed=42');
    await SavedReplayStore.add(uri, contestantNames: ['Ball A', 'Ball/B:*']);
    final saved = (await SavedReplayStore.load()).single;
    expect(saved.name, matches(RegExp(r'^\d{8}_\d{6}_Ball_A_Ball_B.bw$')));
    await SavedReplayStore.rename(saved.id, 'My final');
    await SavedReplayStore.add(uri, contestantNames: ['Other']);
    expect((await SavedReplayStore.load()).single.name, 'My final');
  });

  test(
    'rename persists without changing replay identity or playback data',
    () async {
      OfflineStore.instance = MemoryOfflineStore();
      await SavedReplayStore.add(Uri.parse('https://example.com/?seed=4'));
      final before = (await SavedReplayStore.load()).single;
      await SavedReplayStore.rename(before.id, '  Final laser battle  ');
      final after = (await SavedReplayStore.load()).single;
      expect(after.name, 'Final laser battle');
      expect(after.id, before.id);
      expect(after.uri, before.uri);
      expect(after.savedAt, before.savedAt);
      await SavedReplayStore.rename(before.id, '');
      expect((await SavedReplayStore.load()).single.name, isNull);
    },
  );
}
