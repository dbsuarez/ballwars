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

  test('grip preview can choose slash, thrust and restore legacy', () {
    const original = GripValues();
    final slash = original.copyWith(attackAnimation: HeldAttackAnimation.slash);
    expect(slash.attackAnimation, HeldAttackAnimation.slash);
    final thrust = slash.copyWith(attackAnimation: HeldAttackAnimation.thrust);
    expect(thrust.attackAnimation, HeldAttackAnimation.thrust);
    expect(thrust.copyWith(attackAnimation: null).attackAnimation, isNull);
  });
}
