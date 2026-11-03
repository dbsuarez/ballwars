import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = SkillDefinition(
    id: 'test.artwork', name: 'Artwork test', baseKind: PowerUpKind.pistol,
    iconSpriteId: 'test.icon',
  );

  test('default held sprite uses icon', () {
    expect(original.effectiveHeldSpriteId, 'test.icon');
  });

  test('none hides held sprite without removing pickup artwork', () {
    final skill = original.copyWith(heldSpriteId: SkillDefinition.noHeldArtwork);
    expect(skill.effectiveHeldSpriteId, SkillDefinition.noHeldArtwork);
    expect(skill.effectivePickupSpriteId, 'test.icon');
  });

  test('legacy Firewall flame presentation remains compatible', () {
    final skill = original.copyWith(heldSpriteId: SkillDefinition.flameHandArtwork);
    expect(skill.effectiveHeldSpriteId, SkillDefinition.flameHandArtwork);
  });

  test('effect-only mode is preserved independently of icon', () {
    final value = '${SkillDefinition.handEffectPrefix}lightning';
    expect(original.copyWith(heldSpriteId: value).effectiveHeldSpriteId, value);
  });

  test('combined sprite and hand effect mode is preserved', () {
    final value = '${SkillDefinition.handOverlayPrefix}portal|test.weapon';
    expect(original.copyWith(heldSpriteId: value).effectiveHeldSpriteId, value);
  });
}
