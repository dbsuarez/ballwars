import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Color(0xffff0000),
    glowColor: Color(0xffff0000),
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Color(0xff0000ff),
    glowColor: Color(0xff0000ff),
  ),
];
MatchSimulationController match(SkillDefinition custom, int revision) {
  final m = MatchSimulationController(
    balls,
    arenaRadius: 260,
    seed: 2,
    mode: MatchMode.arsenal,
    lookAhead: false,
    dualWield: true,
    simulationRevision: revision,
    skillLibrary: SkillLibrary.defaults.withDefinition(
      custom,
      PowerUpConfig.defaults,
    ),
  );
  m.powerUps!.automaticSpawning = false;
  m.state.balls[0].position = const Offset(-80, 0);
  m.state.balls[1].position = const Offset(80, 0);
  for (final ball in m.state.balls) {
    ball.velocity = Offset.zero;
  }
  return m;
}

void give(MatchSimulationController m, PowerUpKind kind, {String? id}) {
  final owner = m.state.balls.first;
  final item = FieldPowerUp(
    kind: kind,
    skillId: id,
    position: owner.position,
    spawnStep: 0,
  );
  m.powerUps!.field.add(item);
  m.powerUps!.pickUp(owner, item);
}

void main() {
  final knife = SkillLibrary.defaults.builtIn(
    PowerUpKind.knife,
    PowerUpConfig.defaults,
  );
  final custom = SkillLibrary.defaults
      .duplicate(knife, 'Kutsilyo')
      .copyWith(arsenalDamage: 31);
  test(
    'new matches never infer custom identity from a shared base kind; old links keep their rules',
    () {
      for (final revision in [1, 2, 3]) {
        final m = match(custom, revision);
        give(m, PowerUpKind.knife, id: custom.id);
        give(m, PowerUpKind.knife);
        expect(m.state.balls.first.heldSkillId, custom.id);
        expect(
          m.state.balls.first.heldSecondarySkillId,
          revision < 3 ? custom.id : knife.id,
        );
      }
    },
  );
  for (final customFirst in [true, false]) {
    test(
      'both knife variants retain their own collision damage in either hand ($customFirst)',
      () {
        final m = match(custom, 3),
            owner = m.state.balls.first,
            target = m.state.balls.last;
        give(m, PowerUpKind.knife, id: customFirst ? custom.id : knife.id);
        give(m, PowerUpKind.knife, id: customFirst ? knife.id : custom.id);
        m.powerUps!.onContact(owner, target);
        expect(
          target.life,
          100 - 31 - PowerUpConfig.defaults.arenaDamage(PowerUpKind.knife),
        );
        expect(owner.equippedWeapons, isEmpty);
        expect(
          m.powerUps!.weaponImpacts.map((hit) => hit.skillId),
          contains(knife.id),
        );
      },
    );
  }
  test(
    'firing and discarding a pistol does not consume a different same-carrier skill',
    () {
      final pistol = SkillLibrary.defaults.builtIn(
        PowerUpKind.pistol,
        PowerUpConfig.defaults,
      );
      final customPistol = SkillLibrary.defaults
          .duplicate(pistol, 'Contact Pistol')
          .copyWith(
            trigger: SkillTrigger.collision,
            delivery: SkillDelivery.instant,
            castingSpriteId: 'custom.example.cast',
          );
      for (final revision in [2, 3]) {
        final m = match(customPistol, revision),
            p = m.powerUps!,
            owner = m.state.balls.first;
        give(m, PowerUpKind.pistol, id: customPistol.id);
        give(m, PowerUpKind.pistol, id: pistol.id);
        for (var i = 0; i < 180 && p.shots == 0; i++) {
          p.step();
        }
        expect(p.shots, greaterThan(0));
        if (revision == 3) {
          expect(
            p.castingArtwork,
            isEmpty,
            reason:
                'Firing the built-in must not activate the custom weapon in the other hand.',
          );
        }
        for (var i = 0; i < 35; i++) {
          p.step();
        }
        if (revision == 3) {
          expect(owner.heldSkillId, customPistol.id);
          expect(owner.heldSecondary, isNull);
        } else {
          expect(owner.equippedWeapons, isEmpty);
        }
      }
    },
  );
  test('forced custom trap spawning retains its exact ID', () {
    final trap = SkillLibrary.defaults.duplicate(
      SkillLibrary.defaults.builtIn(PowerUpKind.mine, PowerUpConfig.defaults),
      'Custom Mine',
    );
    final m = match(trap, 3);
    m.powerUps!.spawnTestItem(trap.baseKind, skillId: trap.id);
    // A custom/composed trap is a field skill; its template cannot substitute another definition.
    expect(m.powerUps!.field.single.skillId, trap.id);
  });
}
