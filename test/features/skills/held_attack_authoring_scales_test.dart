import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/grip_preview_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new attack sizes default to legacy appearance, without stored keys', () {
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.sword, PowerUpConfig.defaults);
    expect(base.heldAttackArcScale, 1);
    expect(base.heldAttackVfxScale, 1);
    expect(base.toJson().containsKey('held_attack_arc_scale'), isFalse);
    expect(base.toJson().containsKey('held_attack_vfx_scale'), isFalse);
  });

  test('attack presentation sizes persist independently from damage rules', () {
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.sword, PowerUpConfig.defaults);
    final adjusted = base.copyWith(
        heldAttackAnimation: HeldAttackAnimation.slash,
        heldAttackArcScale: 1.75,
        heldAttackVfxScale: 2.5);
    final recovered = SkillDefinition.fromJson(adjusted.toJson())!;
    expect(recovered.heldAttackArcScale, 1.75);
    expect(recovered.heldAttackVfxScale, 2.5);
    expect(recovered.effectiveAttackDelivery, base.effectiveAttackDelivery);
  });

  test('authoring controls clamp invalid visual strength ranges', () {
    final base = SkillLibrary.defaults.builtIn(
        PowerUpKind.sword, PowerUpConfig.defaults);
    expect(base.copyWith(heldAttackArcScale: 0).heldAttackArcScale, .25);
    expect(base.copyWith(heldAttackArcScale: 99).heldAttackArcScale, 2);
    expect(base.copyWith(heldAttackVfxScale: 0).heldAttackVfxScale, .25);
    expect(base.copyWith(heldAttackVfxScale: 99).heldAttackVfxScale, 3);
    final grip = const GripValues().copyWith(
      attackArcScale: 1.5, attackVfxScale: 2.25,
    );
    expect(grip.attackArcScale, 1.5);
    expect(grip.attackVfxScale, 2.25);
  });
}
