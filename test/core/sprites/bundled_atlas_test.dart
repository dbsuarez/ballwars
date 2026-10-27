// The real bundled atlases: they load without problems, every id the game asks
// for resolves, each sheet is decoded once, and the sheets the old
// SpriteAssetPipeline checked keep their exact frames.
import 'dart:convert';

import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_effect_library.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// rootBundle that counts how often each sheet image is loaded.
class _CountingBundle extends CachingAssetBundle {
  final Map<String, int> loads = {};

  @override
  Future<ByteData> load(String key) {
    if (key.endsWith('.png')) loads[key] = (loads[key] ?? 0) + 1;
    return rootBundle.load(key);
  }
}

Future<SpriteAtlas> _manifest(String path) async =>
    SpriteAtlas.parse(jsonDecode(await rootBundle.loadString(path)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bundle = _CountingBundle();

  setUpAll(() async {
    SpriteRegistry.resetForTest();
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      await SpriteRegistry.load(bundle: bundle);
      // The facade reuses the registry's load (same future).
      await PowerUpSprites.load();
    });
  });

  test('bundled atlases load without problems', () {
    expect(SpriteRegistry.loadProblems, isEmpty);
  });

  test('every id the facade and ArenaEffectLibrary ask for resolves', () {
    final ids = [
      ...PowerUpSprites.requiredIds,
      for (final d in ArenaEffectLibrary.definitions.values)
        if (d.id != null) d.id!,
    ];
    final missing = ids.where((id) => !SpriteRegistry.has(id)).toList();
    expect(missing, isEmpty);
    for (final kind in ArenaEffectKind.values) {
      final definition = ArenaEffectLibrary.definitions[kind]!;
      if (definition.id == null) continue;
      expect(ArenaEffectLibrary.frame(kind, 0), isNotNull, reason: '$kind');
    }
  });

  test('each sheet is decoded once', () async {
    final index =
        (jsonDecode(await rootBundle.loadString(SpriteRegistry.indexPath))
                as List)
            .cast<String>();
    final sheets = {for (final path in index) (await _manifest(path)).sheet};
    expect(bundle.loads.keys.toSet(), sheets);
    expect(
      bundle.loads.values.every((n) => n == 1),
      isTrue,
      reason: '${bundle.loads}',
    );
  });

  // Moved from the old SpriteAssetPipeline tests.
  test(
    'lightning: eight exact 444 px cells that the raw grid cannot hold',
    () async {
      final atlas = await _manifest(
        'assets/sprites/lightning-strike-8.atlas.json',
      );
      expect(atlas.sprites['anim.lightning']!.frames, hasLength(8));
      expect(atlas.problems(sheetSize: const Size(1776, 888)), isEmpty);
      // The raw 1774 x 887 grid (or any smaller sheet) would cut past the edge.
      expect(atlas.problems(sheetSize: const Size(1774, 887)), isNotEmpty);
      expect(atlas.problems(sheetSize: const Size(1775, 888)), isNotEmpty);
      expect(atlas.problems(sheetSize: const Size(1776, 887)), isNotEmpty);
    },
  );

  test('lightning decodes eight isolated 192 px frames', () {
    expect(SpriteRegistry.frameCount('anim.lightning'), 8);
    for (var i = 0; i < 8; i++) {
      final frame = SpriteRegistry.frame('anim.lightning', i)!;
      expect((frame.width, frame.height), (192, 192));
    }
  });

  test('shared lightning animation exposes all eight once-only frames', () {
    final definition =
        ArenaEffectLibrary.definitions[ArenaEffectKind.lightning]!;
    expect(definition.frames, 8);
    expect(definition.stepsPerFrame, 1);
    expect(definition.playback, ArenaEffectPlayback.once);
    final frames = [
      for (var step = 0; step < 8; step++)
        ArenaEffectLibrary.frame(ArenaEffectKind.lightning, step),
    ];
    expect(frames.every((frame) => frame != null), isTrue);
    expect(frames.toSet(), hasLength(8));
    expect(
      ArenaEffectLibrary.frame(ArenaEffectKind.lightning, 99),
      same(frames.last),
    );
  });

  test('tornado: eight 440 px cells inset by 12 px, cut to 96 px', () async {
    final atlas = await _manifest(
      'assets/sprites/tornado-animated-v2.atlas.json',
    );
    final def = atlas.sprites['anim.tornado']!;
    expect(def.frames, [
      for (var i = 0; i < 8; i++)
        Rect.fromLTWH((i % 4) * 440 + 12, (i ~/ 4) * 440 + 12, 416, 416),
    ]);
    expect(atlas.problems(sheetSize: const Size(1760, 880)), isEmpty);
    expect(SpriteRegistry.frameCount('anim.tornado'), 8);
    for (var i = 0; i < 8; i++) {
      final frame = SpriteRegistry.frame('anim.tornado', i)!;
      expect((frame.width, frame.height), (96, 96));
    }
  });

  test('effect timing matches the game before atlases', () {
    const expected = {
      ArenaEffectKind.flame: (4, 3),
      ArenaEffectKind.campfire: (4, 3),
      ArenaEffectKind.explosion: (4, 2),
      ArenaEffectKind.lightning: (8, 1),
      ArenaEffectKind.portal: (4, 3),
      ArenaEffectKind.iceImpact: (4, 2),
      ArenaEffectKind.slash: (4, 2),
      ArenaEffectKind.blood: (4, 2),
      ArenaEffectKind.maximumPower: (4, 3),
    };
    expected.forEach((kind, value) {
      final d = ArenaEffectLibrary.definitions[kind]!;
      expect((d.frames, d.stepsPerFrame), value, reason: '$kind');
    });
  });

  test('sticky goo rim keeps its 768 x 160 strip', () {
    final rim = SpriteRegistry.frame(PowerUpSprites.stickyGooRimId)!;
    expect((rim.width, rim.height), (768, 160));
  });
}
