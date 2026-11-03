import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const effect = ResolvedSkillEffect(
    spriteId: 'missing.png', scale: 1, opacity: 1,
    tint: 0xFFFFFFFF, playback: EffectPlayback.once,
  );

  test('hand placement remains finite even when radius arithmetic overflows', () {
    final result = SkillEffectRenderer.attachment(
      effect, SkillVisualRole.muzzle, const Offset(2, 3),
      owner: const Offset(4, 5), radius: 1e308,
    );
    expect(result, const Offset(4, 5));
  });

  test('nonfinite hand anchor falls back to finite event position', () {
    final result = SkillEffectRenderer.attachment(
      effect, SkillVisualRole.muzzle, const Offset(2, 3),
      owner: Offset(double.infinity, 2),
      direction: const Offset(0, 1), radius: 0,
    );
    expect(result, const Offset(2, 3));
  });

  test('missing sprite does not claim it painted or consume visual budget', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    SkillEffectRenderer.withBudget(1, () {
      expect(SkillEffectRenderer.paint(canvas, effect,
        Offset.zero, 10, 0, 5), isFalse);
      expect(SkillEffectRenderer.takeVisual(), isTrue);
      expect(SkillEffectRenderer.takeVisual(), isFalse);
    });
    recorder.endRecording().dispose();
  });
}
