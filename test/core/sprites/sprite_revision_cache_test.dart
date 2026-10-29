import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ui.Image> image(Color color) async {
    final r = ui.PictureRecorder();
    Canvas(
      r,
    ).drawRect(const Rect.fromLTWH(0, 0, 16, 16), Paint()..color = color);
    final p = r.endRecording();
    final i = await p.toImage(16, 16);
    p.dispose();
    return i;
  }

  setUp(SpriteRegistry.resetForTest);
  tearDown(SpriteRegistry.resetForTest);
  const atlas = SpriteAtlas(
    sheet: 'test',
    sprites: {
      'icon': SpriteDef(
        id: 'icon',
        frames: [Rect.fromLTWH(0, 0, 16, 16)],
        output: 16,
      ),
    },
  );
  test(
    'immutable aliases share frames, survive replacement and obey pin leases',
    () async {
      final red = await image(Colors.red), blue = await image(Colors.blue);
      await SpriteRegistry.register(atlas, red, idPrefix: 'custom.atlas');
      SpriteRegistry.alias(
        'custom.atlas.icon',
        'custom.atlas~old.icon',
        'custom.atlas~old',
      );
      final old = SpriteRegistry.frame('custom.atlas~old.icon');
      expect(SpriteRegistry.decodedBytes, 16 * 16 * 4);
      final release = SpriteRegistry.pin(['custom.atlas~old.icon']);
      await SpriteRegistry.register(atlas, blue, idPrefix: 'custom.atlas');
      expect(SpriteRegistry.frame('custom.atlas~old.icon'), same(old));
      expect(SpriteRegistry.frame('custom.atlas.icon'), isNot(same(old)));
      expect(SpriteRegistry.decodedBytes, 2 * 16 * 16 * 4);
      SpriteRegistry.cacheBudgetBytes = 0;
      SpriteRegistry.trimCache();
      expect(SpriteRegistry.has('custom.atlas~old.icon'), isTrue);
      expect(SpriteRegistry.has('custom.atlas.icon'), isFalse);
      expect(SpriteRegistry.ids, contains('custom.atlas.icon'));
      expect(SpriteRegistry.frameCount('custom.atlas.icon'), 1);
      expect(SpriteRegistry.pinnedBytes, 16 * 16 * 4);
      release();
      release();
      expect(SpriteRegistry.decodedBytes, 0);
      red.dispose();
      blue.dispose();
    },
  );
  test(
    'artwork lookup scope applies to availability and restores after errors',
    () async {
      final source = await image(Colors.green);
      await SpriteRegistry.register(atlas, source, idPrefix: 'custom.revision');
      source.dispose();
      SpriteRegistry.withArtwork({'missing': 'custom.revision.icon'}, () {
        expect(SpriteRegistry.has('missing'), isTrue);
        expect(SpriteRegistry.frame('missing'), isNotNull);
        expect(SpriteRegistry.frameCount('missing'), 1);
      });
      expect(SpriteRegistry.has('missing'), isFalse);
      expect(
        () => SpriteRegistry.withArtwork({
          'missing': 'custom.revision.icon',
        }, () => throw StateError('test')),
        throwsStateError,
      );
      expect(SpriteRegistry.frame('missing'), isNull);
    },
  );
  test(
    'generated artwork travels as a bounded portable PNG with its metadata',
    () async {
      final source = await image(Colors.purple);
      await SpriteRegistry.registerDrawn(
        'qa.generated',
        source,
        output: 16,
        anchor: const Offset(.2, .7),
      );
      source.dispose();
      final alias = 'built.${'a' * 40}.qa.generated';
      SpriteRegistry.alias('qa.generated', alias, 'built.${'a' * 40}');
      final bytes = await SpriteRegistry.frame(
        alias,
      )!.toByteData(format: ui.ImageByteFormat.rawRgba);
      final embedded = await SpriteRegistry.embedDrawn({'qa.generated': alias});
      SpriteRegistry.resetForTest();
      await SpriteRegistry.restoreEmbedded(embedded);
      expect(SpriteRegistry.anchor(alias), const Offset(.2, .7));
      expect(
        (await SpriteRegistry.frame(alias)!.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List(),
        bytes!.buffer.asUint8List(),
      );
      expect(
        () => SpriteRegistry.restoreEmbedded({
          'built.${'b' * 40}.bad': {'png': 'bad'},
        }),
        throwsA(anything),
      );
    },
  );
}
