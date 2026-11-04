import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ballwars/app.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/replay_export/data/short_link_repository.dart';
import 'package:ballwars/features/replay_export/domain/replay_document.dart';
import 'package:ballwars/features/replay_export/presentation/saved_replays_screen.dart';

class _Picker extends FilePicker {
  late Uint8List bytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: 'portable.bw', size: bytes.length, bytes: bytes),
  ]);
}

class _Links implements ShortLinkRepository {
  int calls = 0;
  bool missing = false;
  @override
  Future<String> create(Map<String, String> replayQuery) async => 'abc1234';
  @override
  Future<Map<String, String>?> resolve(String code) async {
    calls++;
    if (missing) return null;
    throw StateError('offline');
  }
}

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  testWidgets('portable replay imports and exports without a server', (
    tester,
  ) async {
    final document = ReplayDocument({
      'seed': '42',
      'balls': 'v.7,m.arsenal,w.0,p.a,p.b',
      'cs': 'custom.boom',
    });
    FilePicker.platform = _Picker()
      ..bytes = Uint8List.fromList(utf8.encode(document.encode()));
    String? fileName;
    ReplayDocument? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: SavedReplaysScreen(
          onOpen: (_) {},
          saveFile: (bytes, name) async {
            fileName = name;
            saved = ReplayDocument.decode(utf8.decode(bytes));
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import .bw replay'));
    await tester.pumpAndSettle();
    expect(
      find.text('portable.bw'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join('|'),
    );
    expect(
      (await SavedReplayStore.load()).single.uri,
      contains('cs=custom.boom'),
    );
    await tester.tap(find.byTooltip('Replay options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save .bw file'));
    await tester.pumpAndSettle();
    expect(fileName, 'portable.bw');
    expect(saved!.query, document.query);
  });

  testWidgets('malformed import reports error and preserves saved replays', (
    tester,
  ) async {
    await SavedReplayStore.add(
      Uri.parse('https://example.com/?seed=1&balls=p.a,p.b'),
    );
    FilePicker.platform = _Picker()
      ..bytes = Uint8List.fromList(utf8.encode('bad data'));
    await tester.pumpWidget(
      MaterialApp(home: SavedReplaysScreen(onOpen: (_) {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import .bw replay'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not import replay'), findsOneWidget);
    expect(await SavedReplayStore.load(), hasLength(1));
  });

  for (final missing in [false, true]) {
    testWidgets(
      'short replay ${missing ? 'missing' : 'offline'} is explained with appropriate retry',
      (tester) async {
        final links = _Links()..missing = missing;
        await SavedReplayStore.add(Uri.parse('https://example.com/?r=abc1234'));
        await tester.pumpWidget(BallWarsApp(shortLinks: links));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved replays'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.play_circle_outline));
        await tester.pumpAndSettle();
        expect(
          find.text(
            missing
                ? 'This replay link no longer exists.'
                : 'Could not load this replay. Check your connection.',
          ),
          findsOneWidget,
        );
        if (!missing) {
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(links.calls, 2);
        }
      },
    );
  }
}
