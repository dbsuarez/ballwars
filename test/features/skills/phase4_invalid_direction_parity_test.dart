
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const effect = ResolvedSkillEffect(
    spriteId: 'test-sprite',
    scale: 1,
    opacity: 1,
    tint: 0xffffffff,
    playback: EffectPlayback.once,
    attachment: EffectAttachment.hand,
  );

  test('invalid direction falls back to right-facing hand attachment', () {
    final point = const Offset(10, 20);
    final actual = SkillEffectRenderer.attachment(
      effect, SkillVisualRole.muzzle, point,
      owner: point, direction: const Offset(double.nan, 1), radius: 10,
    );
    expect(actual, const Offset(21, 20));
  });

  test('zero direction preserves deterministic hand attachment', () {
    final actual = SkillEffectRenderer.attachment(
      effect, SkillVisualRole.muzzle, Offset.zero,
      direction: Offset.zero, radius: 10,
    );
    expect(actual, const Offset(11, 0));
  });
  test('non-finite and negative radius cannot corrupt hand placement', () {
    for (final radius in [double.nan, double.infinity, -10.0]) {
      expect(
        SkillEffectRenderer.attachment(
          effect, SkillVisualRole.muzzle, const Offset(10, 20),
          radius: radius,
        ),
        const Offset(10, 20),
      );
    }
  });

  test('invalid owner and point anchors resolve deterministically', () {
    expect(
      SkillEffectRenderer.attachment(
        effect, SkillVisualRole.muzzle, const Offset(10, 20),
        owner: const Offset(double.infinity, 4), radius: 10,
      ),
      const Offset(21, 20),
    );
    expect(
      SkillEffectRenderer.attachment(
        effect, SkillVisualRole.muzzle, const Offset(double.nan, 2),
        radius: 0,
      ),
      Offset.zero,
    );
  });

  test('valid attachment coordinates remain unchanged', () {
    const targetEffect = ResolvedSkillEffect(
      spriteId: 'test-sprite', scale: 1, opacity: 1, tint: 0xffffffff,
      playback: EffectPlayback.once, attachment: EffectAttachment.target,
    );
    expect(
      SkillEffectRenderer.attachment(
        targetEffect, SkillVisualRole.impact, const Offset(1, 2),
        target: const Offset(30, 40),
      ),
      const Offset(30, 40),
    );
    expect(
      SkillEffectRenderer.attachment(
        targetEffect, SkillVisualRole.impact, const Offset(1, 2),
        target: const Offset(double.nan, 40),
      ),
      const Offset(1, 2),
    );
  });

}
