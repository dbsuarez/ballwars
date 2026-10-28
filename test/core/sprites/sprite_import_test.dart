import 'dart:typed_data';
import 'dart:ui';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_import.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> frame(int x, {bool trimmed = false}) => {
  'frame': {'x': x, 'y': 0, 'w': 8, 'h': 8},
  'duration': 100,
  if (trimmed) 'spriteSourceSize': {'x': 4, 'y': 2, 'w': 8, 'h': 8},
  if (trimmed) 'sourceSize': {'w': 16, 'h': 16},
};
void main() {
  test('single image and four separate icons or animated frames', () {
    expect(
      SpriteImport.grid(
        sheet: 'icon.png',
        width: 64,
        height: 64,
      ).sprites['sprite']!.frames,
      [const Rect.fromLTWH(0, 0, 64, 64)],
    );
    final animated = SpriteImport.grid(
      sheet: 'four.png',
      width: 64,
      height: 64,
      columns: 2,
      rows: 2,
    );
    expect(animated.sprites.length, 1);
    expect(
      animated.sprites['sprite']!.frames.last,
      const Rect.fromLTWH(32, 32, 32, 32),
    );
    expect(
      SpriteImport.grid(
        sheet: 'four.png',
        width: 64,
        height: 64,
        columns: 2,
        rows: 2,
        animation: false,
      ).sprites.length,
      4,
    );
    expect(
      () => SpriteImport.grid(sheet: 'bad', width: 63, height: 64, columns: 2),
      throwsFormatException,
    );
  });
  test('Aseprite hash and array tags have the same frames and timing', () {
    final frames = [frame(0), frame(8), frame(16)];
    final meta = {
      'size': {'w': 24, 'h': 8},
      'frameTags': [
        {'name': 'Idle', 'from': 0, 'to': 1},
        {'name': 'Attack', 'from': 2, 'to': 2},
      ],
    };
    final hash = SpriteImport.metadata({
      'frames': {for (var i = 0; i < frames.length; i++) 'f$i': frames[i]},
      'meta': meta,
    }, sheet: 'a.png');
    final array = SpriteImport.metadata({
      'frames': frames,
      'meta': meta,
    }, sheet: 'a.png');
    expect(spriteAtlasJson(hash), spriteAtlasJson(array));
    expect(hash.sprites['idle']!.stepsPerFrame, 6);
    expect(hash.sprites['attack']!.frames.single.left, 16);
  });
  test('TexturePacker groups numbered frames and preserves trim position', () {
    final atlas = SpriteImport.metadata({
      'frames': {
        'flame_0.png': frame(0, trimmed: true),
        'flame_1.png': frame(8, trimmed: true),
      },
    }, sheet: 'fire.png');
    final sprite = atlas.sprites['flame']!;
    expect(sprite.frames.length, 2);
    expect(sprite.sourceSizes!.first, const Size(16, 16));
    expect(sprite.sourceOffsets!.first, const Offset(4, 2));
    expect(
      spriteAtlasJson(SpriteAtlas.parse(spriteAtlasJson(atlas))),
      spriteAtlasJson(atlas),
    );
  });
  test('rotation, out of bounds tags and excessive frames are refused', () {
    expect(
      () => SpriteImport.metadata({
        'frames': {
          'f': {...frame(0), 'rotated': true},
        },
      }, sheet: 'bad'),
      throwsFormatException,
    );
    expect(
      () => SpriteImport.metadata({
        'frames': [frame(0)],
        'meta': {
          'frameTags': [
            {'name': 'oops', 'from': 0, 'to': 3},
          ],
        },
      }, sheet: 'bad'),
      throwsFormatException,
    );
    expect(
      () => SpriteImport.grid(
        sheet: 'bad',
        width: 1024,
        height: 1024,
        columns: 32,
        rows: 32,
      ),
      throwsFormatException,
    );
  });
  test('bleeding at an internal cell boundary is reported', () {
    final rgba = Uint8List(16 * 8 * 4);
    rgba[(3 * 16 + 7) * 4 + 3] = 255;
    final atlas = SpriteImport.grid(
      sheet: 'leak',
      width: 16,
      height: 8,
      columns: 2,
    );
    expect(SpriteImport.edgeProblems(atlas, rgba, 16, 8), hasLength(1));
    rgba[(3 * 16 + 7) * 4 + 3] = 0;
    rgba[(3 * 16 + 4) * 4 + 3] = 255;
    expect(SpriteImport.edgeProblems(atlas, rgba, 16, 8), isEmpty);
  });
  test(
    'clean-edge trim removes separated neighbor fragments without touching the center',
    () {
      final rgba = Uint8List(32 * 16 * 4);
      for (var y = 5; y < 11; y++) {
        for (final x in [7, 8, 9, 15]) {
          rgba[(y * 32 + x) * 4 + 3] = 255;
        }
      }
      final atlas = SpriteImport.grid(
        sheet: 'leak',
        width: 32,
        height: 16,
        columns: 2,
      );
      final trimmed = SpriteImport.trimToCleanEdges(
        rgba,
        32,
        16,
        atlas.sprites['sprite']!.frames,
      );
      expect(trimmed.first.right, 15);
      expect(trimmed.first.contains(const Offset(8, 8)), isTrue);
    },
  );
}
