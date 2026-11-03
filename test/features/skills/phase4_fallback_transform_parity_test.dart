import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captured fallback frame supports all facing modes and transforms', () async {
    final source = ui.PictureRecorder();
    ui.Canvas(source).drawRect(
      const ui.Rect.fromLTWH(0, 0, 12, 12),
      ui.Paint()..color = const ui.Color(0xFFFF3300),
    );
    final picture = source.endRecording();
    final image = await picture.toImage(12, 12);
    try {
      for (final facing in EffectFacing.values) {
        final effect = ResolvedSkillEffect(
          spriteId: 'fallback-test.png',
          scale: 1.3,
          opacity: 0.75,
          tint: 0xFFFFFFFF,
          playback: EffectPlayback.once,
          facing: facing,
          rotationDegrees: 27,
          offsetX: 0.5,
          offsetY: -0.25,
        );
        for (final direction in [
          const ui.Offset(1, 0),
          const ui.Offset(-1, 0),
          const ui.Offset(0, -1),
        ]) {
          final target = ui.PictureRecorder();
          final canvas = ui.Canvas(target);
          SkillEffectRenderer.paintImage(
            canvas, effect, image, const ui.Offset(50, 50), 10,
            direction: direction, unitRadius: 8, fade: 0.5,
          );
          final result = target.endRecording();
          final rendered = await result.toImage(100, 100);
          expect(rendered.width, 100);
          rendered.dispose();
          result.dispose();
        }
      }
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
}
