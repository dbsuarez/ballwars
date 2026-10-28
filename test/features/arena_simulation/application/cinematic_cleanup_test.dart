import 'package:flutter/material.dart';
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
    primaryColor: Colors.red,
    glowColor: Colors.red,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.blue,
  ),
  CustomBall(
    id: 'c',
    name: 'C',
    primaryColor: Colors.green,
    glowColor: Colors.green,
  ),
];
MatchSimulationController match(
  int revision, {
  SkillLibrary library = SkillLibrary.defaults,
  int ballCount = 3,
}) {
  final m = MatchSimulationController(
    balls.take(ballCount).toList(),
    arenaRadius: 260,
    seed: 9,
    lookAhead: false,
    mode: MatchMode.arsenal,
    dualWield: true,
    endlessBattle: true,
    simulationRevision: revision,
    skillLibrary: library,
  );
  m.powerUps!.automaticSpawning = false;
  for (var i = 0; i < ballCount; i++) {
    m.state.balls[i].position = Offset(i * 100.0 - 100, 0);
    m.state.balls[i].velocity = Offset(10 + i.toDouble(), 3);
  }
  return m;
}

void give(MatchSimulationController m, PowerUpKind kind) {
  final owner = m.state.balls.first,
      item = FieldPowerUp(kind: kind, position: owner.position, spawnStep: 0);
  m.powerUps!.field.add(item);
  m.powerUps!.pickUp(owner, item);
}

void main() {
  for (final kind in [PowerUpKind.shadowClone, PowerUpKind.ragingDemon]) {
    test(
      '$kind respawn cancels its attack and releases other balls in new rules only',
      () {
        for (final revision in [1, 2]) {
          final m = match(revision), p = m.powerUps!, target = m.state.balls[1];
          give(m, kind);
          expect(m.state.balls.last.stunnedLeft, greaterThan(0));
          p.resetForRespawn(target);
          p.step();
          if (revision == 2) {
            expect(p.shadowCloneAttacks, isEmpty);
            expect(p.ragingDemonAttacks, isEmpty);
            expect(m.state.balls.last.stunnedLeft, 0);
            expect(m.state.balls.last.velocity, const Offset(12, 3));
          } else {
            expect(m.state.balls.last.stunnedLeft, greaterThan(0));
          }
        }
      },
    );
  }
  test(
    'early clone disappearance releases its freeze without erasing an independent stun',
    () {
      final m = match(2), p = m.powerUps!, other = m.state.balls.last;
      other.stunnedLeft = 200;
      give(m, PowerUpKind.shadowClone);
      final attack = p.shadowCloneAttacks.single;
      attack.vanishAt = 0;
      attack.age = ShadowCloneAttack.vanishSteps - 1;
      p.step();
      expect(p.shadowCloneAttacks, isEmpty);
      expect(m.state.balls.first.stunnedLeft, 0);
      expect(other.stunnedLeft, 199);
    },
  );
  test(
    'overlapping cinematics keep time frozen until the final sequence ends',
    () {
      final m = match(2), p = m.powerUps!;
      give(m, PowerUpKind.shadowClone);
      give(m, PowerUpKind.ragingDemon);
      p.shadowCloneAttacks.clear();
      p.step();
      expect(m.state.balls.last.stunnedLeft, greaterThan(0));
      p.ragingDemonAttacks.clear();
      p.step();
      expect(m.state.balls.last.stunnedLeft, 0);
      expect(m.state.balls.last.velocity, const Offset(12, 3));
    },
  );
  test(
    'a secondary-only custom blade uses its damage and credit, with legacy behavior preserved',
    () {
      final custom = SkillLibrary.defaults
          .create('Heavy Knife', PowerUpKind.knife)
          .copyWith(arsenalDamage: 31, trigger: SkillTrigger.collision);
      final library = SkillLibrary.defaults.withDefinition(
        custom,
        PowerUpConfig.defaults,
      );
      for (final revision in [1, 2]) {
        final m = match(revision, library: library, ballCount: 2),
            owner = m.state.balls.first,
            target = m.state.balls[1];
        owner.heldSecondary = PowerUpKind.knife;
        owner.heldSecondarySkillId = custom.id;
        m.powerUps!.onContact(owner, target);
        expect(
          target.life,
          revision == 2
              ? 69
              : 100 - PowerUpConfig.defaults.arenaDamage(PowerUpKind.knife),
        );
      }
    },
  );
}
