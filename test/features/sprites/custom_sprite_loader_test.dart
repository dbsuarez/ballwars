import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/sprites/application/custom_sprite_loader.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSpriteRepository implements SpriteAtlasRepository {
  List<CustomAtlas> items = [];
  bool fails = false;
  @override
  Future<List<CustomAtlas>> list() async {
    if (fails) throw StateError('offline');
    return items;
  }

  @override
  Future<void> delete(String id) async => items.removeWhere((a) => a.id == id);
  @override
  Future<CustomAtlas> save({
    String? id,
    DateTime? expectedUpdatedAt,
    bool restoreMissing = false,
    required String name,
    required Uint8List sheet,
    required String contentType,
    required SpriteAtlas atlas,
  }) async => throw UnimplementedError();
}

CustomAtlas custom(String id) => CustomAtlas(
  id: id,
  name: id,
  sheetUrl: 'https://example.test/$id.png',
  sheetPath: '$id/a.png',
  atlas: SpriteImport.grid(sheet: '$id.png', width: 16, height: 16),
  updatedAt: DateTime.utc(2026),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(SpriteRegistry.resetForTest);
  test(
    'sheet dimensions are read from decoded pixels on web and native',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final picture = ui.PictureRecorder();
        ui.Canvas(picture);
        final drawing = picture.endRecording();
        final original = await drawing.toImage(4097, 1);
        final bytes = (await original.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        original.dispose();
        drawing.dispose();
        final source = await validateSpriteSheet(
          bytes,
          'image/png',
          source: true,
        );
        expect(source.width, 4097);
        expect(source.height, 1);
        source.dispose();
        await expectLater(
          validateSpriteSheet(bytes, 'image/png'),
          throwsFormatException,
        );
      });
    },
  );
  test('custom atlas round trip retains geometry', () {
    final a = custom('first');
    expect(CustomAtlas.fromJson(a.toJson()).toJson(), a.toJson());
  });
  test(
    'two atlases register; corrupt one is isolated; deletion unregisters',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawCircle(
          const ui.Offset(8, 8),
          4,
          ui.Paint()..color = const ui.Color(0xffff0000),
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 16);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
        final repo = FakeSpriteRepository()
          ..items = [custom('first'), custom('bad'), custom('second')];
        var fetches = 0;
        final loader = CustomSpriteLoader(
          repo,
          fetch: (u) async {
            fetches++;
            return u.path.contains('bad') ? Uint8List(4) : bytes;
          },
        );
        final firstLoad = loader.load();
        expect(identical(firstLoad, loader.load()), isTrue);
        await firstLoad;
        expect(SpriteRegistry.has('custom.first.sprite'), isTrue);
        expect(SpriteRegistry.has('custom.second.sprite'), isTrue);
        expect(loader.problems, hasLength(1));
        repo.items = [custom('second')];
        await loader.load();
        expect(SpriteRegistry.has('custom.first.sprite'), isFalse);
        expect(
          fetches,
          3,
          reason: 'An unchanged second atlas keeps its decoded frames',
        );
        repo.fails = true;
        await loader.load();
        expect(SpriteRegistry.has('custom.second.sprite'), isTrue);
      });
    },
  );
  test(
    'oversized and disguised JPEG are refused before decode or upload',
    () async {
      await expectLater(
        validateSpriteSheet(Uint8List(4194305), 'image/png'),
        throwsFormatException,
      );
      await expectLater(
        validateSpriteSheet(
          Uint8List.fromList([255, 216, 255, 0]),
          'image/png',
        ),
        throwsFormatException,
      );
    },
  );
}
