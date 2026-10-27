import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/replay_export/data/short_link_repository.dart';
import 'package:ballwars/features/replay_export/presentation/saved_replays_screen.dart';

class _Links implements ShortLinkRepository {
  int uploads = 0;
  Map<String, String>? uploaded;
  @override
  Future<String> create(Map<String, String> query) async {
    uploads++;
    uploaded = query;
    return 'abc1234';
  }

  @override
  Future<Map<String, String>?> resolve(String code) async => uploaded;
}

void main() {
  testWidgets('upload is optional and the copied short link is reused', (
    tester,
  ) async {
    OfflineStore.instance = MemoryOfflineStore();
    final uri = Uri.parse('https://example.com/?seed=42&balls=p.a,p.b&hair=1');
    await tester.runAsync(() => SavedReplayStore.add(uri));
    final links = _Links();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SavedReplaysScreen(onOpen: (_) {}, shortLinks: links),
      ),
    );
    await tester.pumpAndSettle();
    expect(links.uploads, 0);
    await tester.tap(find.byTooltip('Replay options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create share link'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pumpAndSettle();
    expect(links.uploads, 1);
    expect(links.uploaded?['hair'], '1');
    expect(copied, 'https://example.com/?r=abc1234');
    final saved = await tester.runAsync(() => SavedReplayStore.load());
    expect(saved!.single.uri, uri.toString());
    expect(saved.single.shareUri, copied);
    await tester.tap(find.byTooltip('Replay options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy share link'));
    await tester.pumpAndSettle();
    expect(links.uploads, 1);
  });
}
