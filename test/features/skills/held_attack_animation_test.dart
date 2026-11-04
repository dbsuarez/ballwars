import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/grip_preview_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy skill omits attack animation to preserve saved snapshots', () {
    final skill = SkillLibrary.defaults.builtIn(
      PowerUpKind.sword, PowerUpConfig.defaults);
    expect(skill.heldAttackAnimation, isNull);
    expect(skill.heldAttackRepeatCount, 1);
    expect(skill.toJson().containsKey('held_attack_repeat_count'), isFalse);
    expect(skill.toJson().containsKey('held_attack_animation'), isFalse);
  });

  test('slash is cosmetic and round-trips without changing delivery', () {
    final original = SkillLibrary.defaults.builtIn(
      PowerUpKind.sword, PowerUpConfig.defaults);
    final edited = original.copyWith(heldAttackAnimation: HeldAttackAnimation.slash);
    expect(edited.effectiveAttackDelivery, original.effectiveAttackDelivery);
    expect(edited.toJson()['held_attack_animation'], 'slash');
    final restored = SkillDefinition.fromJson(edited.toJson());
    expect(restored!.heldAttackAnimation, HeldAttackAnimation.slash);
    expect(restored.effectiveAttackDelivery, original.effectiveAttackDelivery);
  });

  test('repeat count is visual-only, clamped and persists on saved skills', () {
    final base = SkillLibrary.defaults.builtIn(
      PowerUpKind.sword, PowerUpConfig.defaults);
    final edited = base.copyWith(heldAttackAnimation: HeldAttackAnimation.slash,
        heldAttackRepeatCount: 3);
    expect(edited.toJson()['held_attack_repeat_count'], 3);
    final restored = SkillDefinition.fromJson(edited.toJson())!;
    expect(restored.heldAttackRepeatCount, 3);
    expect(restored.effectiveAttackDelivery, base.effectiveAttackDelivery);
    expect(edited.copyWith(heldAttackRepeatCount: 0).heldAttackRepeatCount, 1);
    expect(edited.copyWith(heldAttackRepeatCount: 100).heldAttackRepeatCount, 5);
    expect(const GripValues().copyWith(attackRepeatCount: 4).attackRepeatCount, 4);
  });

  test('melee visual duration is persisted without changing damage delivery', () {
    final base = SkillLibrary.defaults.builtIn(
      PowerUpKind.sword, PowerUpConfig.defaults);
    expect(base.heldAttackDurationSteps, 30);
    expect(base.toJson().containsKey('held_attack_duration_steps'), isFalse);
    final edited = base.copyWith(heldAttackDurationSteps: 60);
    expect(edited.toJson()['held_attack_duration_steps'], 60);
    final loaded = SkillDefinition.fromJson(edited.toJson())!;
    expect(loaded.heldAttackDurationSteps, 60);
    expect(loaded.effectiveAttackDelivery, base.effectiveAttackDelivery);
    expect(base.copyWith(heldAttackDurationSteps: 0).heldAttackDurationSteps, 12);
    expect(base.copyWith(heldAttackDurationSteps: 900).heldAttackDurationSteps, 90);
    expect(const GripValues().copyWith(attackDurationSteps: 45).attackDurationSteps, 45);
  });

  test('Held Attack VFX is independent of direct-hit impact and survives save', () {
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.sword, PowerUpConfig.defaults);
    final changed = base.copyWith(
      heldAttackAnimation: HeldAttackAnimation.slash,
      heldAttackVfxSpriteId: 'custom.crescent.sprite',
      impactSpriteId: 'custom.hit.sprite',
    );
    final restored = SkillDefinition.fromJson(changed.toJson())!;
    expect(restored.heldAttackVfxSpriteId, 'custom.crescent.sprite');
    expect(restored.impactSpriteId, 'custom.hit.sprite');
    expect(restored.effectiveAttackDelivery, base.effectiveAttackDelivery);
    expect(changed.copyWith(heldAttackVfxSpriteId: null).heldAttackVfxSpriteId, isNull);
    expect(base.toJson().containsKey('held_attack_vfx_sprite'), isFalse);
  });

  test('grip preview can choose slash, thrust and restore legacy', () {
    const original = GripValues();
    final slash = original.copyWith(attackAnimation: HeldAttackAnimation.slash);
    expect(slash.attackAnimation, HeldAttackAnimation.slash);
    final thrust = slash.copyWith(attackAnimation: HeldAttackAnimation.thrust);
    expect(thrust.attackAnimation, HeldAttackAnimation.thrust);
    expect(thrust.copyWith(attackAnimation: null).attackAnimation, isNull);
  });
}

// An unchanged legacy save defaults to exactly one visual attack.
