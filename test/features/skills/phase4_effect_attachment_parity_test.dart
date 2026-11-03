
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const visual = ResolvedSkillEffect(
    spriteId: 'hit.png',
    scale: 1,
    opacity: 1,
    tint: 0xFFFFFFFF,
    playback: EffectPlayback.once,
  );

  test('automatic casting follows owner rather than hit location', () {
    expect(
      SkillEffectRenderer.attachment(
        visual,
        SkillVisualRole.casting,
        const Offset(50, 20),
        owner: const Offset(8, 9),
      ),
      const Offset(8, 9),
    );
  });

  test('automatic impact and explosion attach at the hit location', () {
    for (final role in [SkillVisualRole.impact, SkillVisualRole.explosion]) {
      expect(
        SkillEffectRenderer.attachment(
          visual,
          role,
          const Offset(50, 20),
          owner: const Offset(8, 9),
          target: const Offset(80, 90),
        ),
        const Offset(50, 20),
      );
    }
  });

  test('explicit target attachment overrides automatic hit location', () {
    const targetVisual = ResolvedSkillEffect(
      spriteId: 'hit.png',
      scale: 1,
      opacity: 1,
      tint: 0xFFFFFFFF,
      playback: EffectPlayback.once,
      attachment: EffectAttachment.target,
    );
    expect(
      SkillEffectRenderer.attachment(
        targetVisual,
        SkillVisualRole.impact,
        const Offset(50, 20),
        target: const Offset(80, 90),
      ),
      const Offset(80, 90),
    );
  });

  test('automatic attachment matrix covers status, muzzle, trail and breakage', () {
    const point = Offset(50, 20);
    const owner = Offset(8, 9);
    const target = Offset(80, 90);
    for (final role in [SkillVisualRole.casting, SkillVisualRole.ownerStatus,
      SkillVisualRole.discard]) {
      expect(SkillEffectRenderer.attachment(visual, role, point,
        owner: owner, target: target), owner, reason: role.name);
    }
    for (final role in [SkillVisualRole.targetStatus, SkillVisualRole.block,
      SkillVisualRole.breakage]) {
      expect(SkillEffectRenderer.attachment(visual, role, point,
        owner: owner, target: target), target, reason: role.name);
    }
    expect(SkillEffectRenderer.attachment(visual, SkillVisualRole.muzzle,
      point, owner: owner, direction: const Offset(0, 1), radius: 10),
      const Offset(8, 20));
    expect(SkillEffectRenderer.attachment(visual, SkillVisualRole.trail,
      point, owner: owner, target: target), point);
  });

  test('zero direction has deterministic hand attachment fallback', () {
    expect(SkillEffectRenderer.attachment(visual, SkillVisualRole.muzzle,
      const Offset(0, 0), owner: const Offset(3, 4),
      direction: Offset.zero, radius: 10), const Offset(14, 4));
  });

}
