import 'dart:typed_data';
import 'dart:ui';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'per-sprite rename, timing, anchor and reordered trimmed frames remain aligned',
    () {
      const sprite = SpriteDef(
        id: 'old',
        frames: [Rect.fromLTWH(0, 0, 4, 4), Rect.fromLTWH(4, 0, 4, 4)],
        output: 16,
        sourceSizes: [Size(8, 8), Size(10, 10)],
        sourceOffsets: [Offset(1, 1), Offset(2, 2)],
      );
      final edit = SpriteEdit()
        ..name = 'new'
        ..stepsPerFrame = 12
        ..anchor = const Offset(0, 1)
        ..order = [1, 0];
      final result = edit.apply(sprite);
      expect(result.id, 'new');
      expect(result.stepsPerFrame, 12);
      expect(result.anchor, const Offset(0, 1));
      expect(result.frames.first, sprite.frames.last);
      expect(result.sourceSizes!.first, const Size(10, 10));
      expect(result.sourceOffsets!.first, const Offset(2, 2));
      edit.excluded.add(0);
      expect(edit.apply(sprite).frames, [sprite.frames.last]);
      edit.excluded.add(1);
      expect(() => edit.apply(sprite), throwsFormatException);
      edit.excluded.clear();
      edit.name = ' ';
      expect(() => edit.apply(sprite), throwsFormatException);
    },
  );
  test(
    'diagnostics identify blank frames, partial alpha, visible bounds and edges',
    () {
      final rgba = Uint8List(8 * 4 * 4);
      rgba[(1 * 8 + 1) * 4 + 3] = 128;
      rgba[(1 * 8 + 3) * 4 + 3] = 255;
      final filled = SpriteFrameDiagnostics.inspect(
        rgba,
        8,
        4,
        const Rect.fromLTWH(0, 0, 4, 4),
      );
      expect(filled.visible, 2);
      expect(filled.partial, 1);
      expect(filled.edges, 1);
      expect(filled.bounds, const Rect.fromLTWH(1, 1, 3, 1));
      final blank = SpriteFrameDiagnostics.inspect(
        rgba,
        8,
        4,
        const Rect.fromLTWH(4, 0, 4, 4),
      );
      expect(blank.blank, isTrue);
      expect(blank.transparencyPercent, 100);
    },
  );
}
