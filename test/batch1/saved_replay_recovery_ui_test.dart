import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/replay_export/presentation/saved_replays_screen.dart';

class _Store extends MemoryOfflineStore {
  bool failReads = false, failWrites = false;
  @override
  Future<Uint8List?> read(String key) async {
    if (failReads) throw StateError('Storage unavailable');
    return super.read(key);
  }

  @override
  Future<void> write(String key, Uint8List value) async {
    if (failWrites) throw StateError('Disk full');
    await super.write(key, value);
  }
}

void main() {
  testWidgets('unreadable replay list has retry feedback and recovers', (
    tester,
  ) async {
    final store = _Store();
    OfflineStore.instance = store;
    await tester.runAsync(
      () => SavedReplayStore.add(Uri.parse('https://example.com/?seed=1')),
    );
    store.failReads = true;
    await tester.pumpWidget(
      MaterialApp(home: SavedReplaysScreen(onOpen: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Saved replays could not be loaded'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    store.failReads = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
  });
  testWidgets(
    'failed delete remains visible and the stored replay is retained',
    (tester) async {
      final store = _Store();
      OfflineStore.instance = store;
      await tester.runAsync(
        () => SavedReplayStore.add(Uri.parse('https://example.com/?seed=1')),
      );
      await tester.pumpWidget(
        MaterialApp(home: SavedReplaysScreen(onOpen: (_) {})),
      );
      await tester.pumpAndSettle();
      store.failWrites = true;
      await tester.tap(find.byTooltip('Replay options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Replay could not be deleted'),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsOneWidget);
      store.failWrites = false;
      expect((await tester.runAsync(SavedReplayStore.load))!, hasLength(1));
    },
  );
}
