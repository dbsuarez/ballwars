import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arenas/presentation/arena_background_import.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';

class _Repository implements SpriteAtlasRepository {
  bool fail = true;
  Uint8List? uploaded;
  @override
  Future<List<CustomAtlas>> list() async => [];
  @override
  Future<void> delete(String id) async {}
  @override
  Future<CustomAtlas> save({
    String? id,
    DateTime? expectedUpdatedAt,
    bool restoreMissing = false,
    required String name,
    required Uint8List sheet,
    required String contentType,
    required SpriteAtlas atlas,
  }) async {
    expect(
      id,
      isNull,
    ); // New upload must INSERT, never replace a nonexistent ID.
    if (fail) throw StateError('offline');
    expect(contentType, 'image/png');
    expect(atlas.isArenaBackground, true);
    uploaded = sheet;
    return CustomAtlas(
      id: '11111111-1111-4111-8111-111111111111',
      name: name,
      sheetUrl: 'https://example.test/bg.png',
      sheetPath:
          '11111111-1111-4111-8111-111111111111/22222222-2222-4222-8222-222222222222.png',
      atlas: atlas,
      updatedAt: DateTime.utc(2026),
    );
  }
}

void main() {
  testWidgets(
    'crop upload resizes first, keeps draft on failure and registers frozen background',
    (tester) async {
      final repository = _Repository();
      late Uint8List bytes;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 1600, 900),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final source = await picture.toImage(1600, 900);
        bytes = (await source.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        source.dispose();
        picture.dispose();
      });
      String? result;
      await tester.pumpWidget(
        AppSettingsScope(
          settings: ValueNotifier(AppSettings.defaults),
          sprites: repository,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ArenaBackgroundImport(pickImage: () async => bytes),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose image'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Source:'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('1600 × 900'), findsOneWidget);
      await tester.tap(find.text('Upload background'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Your crop is kept'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.text('Upload background'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();
      expect(result, 'custom.11111111-1111-4111-8111-111111111111.background');
      expect(
        SpriteRegistry.frozenIds[result],
        contains('~22222222-2222-4222-8222-222222222222.background'),
      );
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(repository.uploaded!);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 900);
        expect(image.height, 900);
        image.dispose();
        codec.dispose();
      });
      SpriteRegistry.unregister('custom.11111111-1111-4111-8111-111111111111');
    },
  );
}
