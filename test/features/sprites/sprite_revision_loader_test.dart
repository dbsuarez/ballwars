import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/sprites/application/custom_sprite_loader.dart';
import 'package:ballwars/features/sprites/data/sprite_atlas_repository.dart';
import 'custom_sprite_loader_test.dart' show FakeSpriteRepository;

class RevisionRepository extends FakeSpriteRepository
    implements SpriteRevisionRepository {
  final archived = <String, CustomAtlas>{};
  @override
  Future<CustomAtlas?> loadRevision(String id, String revision) async =>
      archived['$id/$revision'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(SpriteRegistry.resetForTest);
  tearDown(SpriteRegistry.resetForTest);
  const id = '11111111-1111-1111-1111-111111111111',
      old = '22222222-2222-2222-2222-222222222222',
      next = '33333333-3333-3333-3333-333333333333';
  CustomAtlas atlas(String rev) => CustomAtlas(
    id: id,
    name: 'Archive',
    sheetUrl: 'https://example.test/$rev.png',
    sheetPath: '$id/$rev.png',
    atlas: SpriteAtlas(
      sheet: 'sheet',
      sprites: {
        'icon': SpriteDef(
          id: 'icon',
          frames: const [ui.Rect.fromLTWH(0, 0, 16, 16)],
          output: 16,
        ),
      },
    ),
    updatedAt: DateTime.utc(2026),
  );
  Future<Uint8List> png(int color) async {
    final r = ui.PictureRecorder();
    ui.Canvas(r).drawRect(
      const ui.Rect.fromLTWH(0, 0, 16, 16),
      ui.Paint()..color = ui.Color(color),
    );
    final p = r.endRecording(), i = await p.toImage(16, 16);
    final b = (await i.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    i.dispose();
    p.dispose();
    return b;
  }

  test(
    'replacement preserves old revision and fresh replay restores it after deletion',
    () async {
      final red = await png(0xffff0000), blue = await png(0xff0000ff);
      final repo = RevisionRepository()
        ..items = [atlas(old)]
        ..archived['$id/$old'] = atlas(old);
      Future<Uint8List> fetch(Uri uri) async =>
          uri.path.contains(old) ? red : blue;
      final loader = CustomSpriteLoader(repo, fetch: fetch);
      await loader.load();
      final oldId = 'custom.$id~$old.icon', newId = 'custom.$id~$next.icon';
      final original = SpriteRegistry.frame(oldId);
      expect(original, isNotNull);
      repo.items = [atlas(next)];
      await loader.load();
      expect(SpriteRegistry.frame(oldId), same(original));
      expect(SpriteRegistry.frame(newId), isNot(same(original)));
      repo.items = [];
      SpriteRegistry.resetForTest();
      await CustomSpriteLoader(repo, fetch: fetch).loadRevisions({oldId});
      expect(SpriteRegistry.has(oldId), isTrue);
      expect(SpriteRegistry.has('custom.$id.icon'), isFalse);
    },
  );
  test(
    'missing archived revision never substitutes the current revision',
    () async {
      final repo = RevisionRepository()..items = [atlas(next)];
      final loader = CustomSpriteLoader(
        repo,
        fetch: (_) => throw StateError('must not fetch a replacement'),
      );
      await loader.loadRevisions({'custom.$id~$old.icon'});
      expect(SpriteRegistry.has('custom.$id~$old.icon'), isFalse);
      expect(loader.problems.single, contains('not found'));
    },
  );
  test(
    'bundled revisions resolve only from the immutable repository commit',
    () async {
      final bytes = await png(0xff00ff00), commit = 'a' * 40;
      final manifest = SpriteAtlas(
        sheet: 'assets/sprites/old.png',
        sprites: {
          'qa.old': const SpriteDef(
            id: 'qa.old',
            frames: [ui.Rect.fromLTWH(0, 0, 16, 16)],
            output: 16,
          ),
        },
      );
      final requests = <Uri>[];
      final loader = CustomSpriteLoader(
        null,
        fetch: (uri) async {
          requests.add(uri);
          if (uri.path.endsWith('atlas-index.json')) {
            return utf8.encode(jsonEncode(['assets/sprites/old.json']));
          }
          if (uri.path.endsWith('old.json')) {
            return utf8.encode(jsonEncode(spriteAtlasJson(manifest)));
          }
          return bytes;
        },
      );
      await loader.loadRevisions({'built.$commit.qa.old'});
      expect(SpriteRegistry.has('built.$commit.qa.old'), isTrue);
      expect(
        requests.every(
          (u) =>
              u.host == 'raw.githubusercontent.com' &&
              u.path.startsWith('/dbsuarez/ballwars/$commit/'),
        ),
        isTrue,
      );
    },
  );
}
