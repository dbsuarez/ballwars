import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every frame of every bundled sheet must have a transparent 2 px border, so
/// neighbouring art can never bleed into a cut frame. Sprites that set
/// bleedOk (with a note) are exempt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled frames have transparent borders', () async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      final index = jsonDecode(
        await rootBundle.loadString(SpriteRegistry.indexPath),
      );
      expect(index, isA<List>());
      final failures = <String>[];
      for (final path in (index as List).cast<String>()) {
        final atlas = SpriteAtlas.parse(
          jsonDecode(await rootBundle.loadString(path)),
        );
        final data = await rootBundle.load(atlas.sheet);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final sheet = (await codec.getNextFrame()).image;
        codec.dispose();
        final bytes = (await sheet.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final def in atlas.sprites.values) {
          if (def.bleedOk) continue;
          for (var i = 0; i < def.frames.length; i++) {
            final f = def.frames[i];
            final x0 = f.left.floor(), x1 = f.right.ceil();
            final y0 = f.top.floor(), y1 = f.bottom.ceil();
            var bad = 0;
            for (var y = y0; y < y1; y++) {
              for (var x = x0; x < x1; x++) {
                final border =
                    x < x0 + 2 || x >= x1 - 2 || y < y0 + 2 || y >= y1 - 2;
                if (border &&
                    bytes.getUint8((y * sheet.width + x) * 4 + 3) > 24) {
                  bad++;
                }
              }
            }
            if (bad > 0) {
              failures.add(
                '${atlas.sheet}: ${def.id} frame ${i + 1} has $bad opaque '
                'border pixels',
              );
            }
          }
        }
        sheet.dispose();
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });
}
