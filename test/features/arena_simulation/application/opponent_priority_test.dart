import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/combat_targeting.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const balls = [
  CustomBall(
    id: 'owner',
    name: 'Owner',
    primaryColor: Colors.red,
    glowColor: Colors.red,
  ),
  CustomBall(
    id: 'near',
    name: 'Near',
    primaryColor: Colors.blue,
    glowColor: Colors.blue,
  ),
  CustomBall(
    id: 'far',
    name: 'Far',
    primaryColor: Colors.green,
    glowColor: Colors.green,
  ),
];

MatchSimulationController setup(SkillLibrary library) {
  final match = MatchSimulationController(
    balls,
    arenaRadius: 260,
    seed: 5,
    simulationRevision: 11,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library,
    dualWield: true,
    powerUpKinds: const {},
  );
  final positions = [Offset.zero, const Offset(80, 0), const Offset(-190, 0)];
  for (var i = 0; i < 3; i++) {
    final ball = match.state.balls[i];
    ball.position = positions[i];
    ball.velocity = Offset.zero;
    ball.life = 1000;
    match.setTestBallPinned(ball, true);
  }
  return match;
}

void main() {
  test(
    'invalid imported priority is rejected instead of silently choosing a target',
    () {
      final skill = SkillLibrary.defaults.builtIn(
        PowerUpKind.busterSword,
        PowerUpConfig.defaults,
      );
      expect(
        SkillDefinition.fromJson({
          ...skill.toJson(),
          'opponent_priority': 'random',
        }),
        isNull,
      );
    },
  );
  test('composed pickup skills use the same opponent priority', () {
    const skill = SkillDefinition(
      id: 'custom.far-strike',
      name: 'Far Strike',
      baseKind: PowerUpKind.pistol,
      custom: true,
      category: SkillCategory.powerUp,
      trigger: SkillTrigger.pickup,
      targeting: SkillTargeting.nearestOpponent,
      delivery: SkillDelivery.instant,
      effectType: SkillEffectType.damage,
      arsenalDamage: 9,
      opponentPriority: OpponentPriority.farthest,
    );
    final match = setup(
      SkillLibrary.defaults.withDefinition(skill, PowerUpConfig.defaults),
    );
    match.powerUps!.pickUp(
      match.state.balls.first,
      FieldPowerUp(
        kind: skill.baseKind,
        skillId: skill.id,
        position: Offset.zero,
        spawnStep: 0,
      ),
    );
    expect(match.state.balls[1].life, 1000);
    expect(match.state.balls[2].life, lessThan(1000));
  });
  test('farthest selection keeps stable ties and excludes ghost opponents', () {
    final match = setup(SkillLibrary.defaults);
    final owner = match.state.balls[0],
        near = match.state.balls[1],
        far = match.state.balls[2];
    far.ghostLeft = 10;
    expect(
      CombatTargeting.select(
        origin: owner.position,
        candidates: match.state.balls,
        owner: owner,
        farthest: true,
      ),
      same(near),
    );
    far.ghostLeft = 0;
    far.position = const Offset(-80, 0);
    for (final candidates in [
      [near, far],
      [far, near],
    ]) {
      expect(
        CombatTargeting.select(
          origin: owner.position,
          candidates: candidates,
          owner: owner,
          farthest: true,
        ),
        same(far),
      );
    }
  });
  test(
    'native homing shots retain their configured priority when retargeting',
    () {
      final skill = SkillLibrary.defaults
          .builtIn(PowerUpKind.rocketLauncher, PowerUpConfig.defaults)
          .copyWith(opponentPriority: OpponentPriority.farthest);
      final match = MatchSimulationController(
        [
          ...balls,
          const CustomBall(
            id: 'middle',
            name: 'Middle',
            primaryColor: Colors.purple,
            glowColor: Colors.purple,
          ),
        ],
        arenaRadius: 260,
        seed: 5,
        simulationRevision: 11,
        mode: MatchMode.arsenal,
        lookAhead: false,
        powerUpKinds: const {},
        skillLibrary: SkillLibrary.defaults.withDefinition(
          skill,
          PowerUpConfig.defaults,
        ),
      );
      final positions = [
        Offset.zero,
        const Offset(80, 0),
        const Offset(-190, 0),
        const Offset(0, 120),
      ];
      for (var i = 0; i < 4; i++) {
        final ball = match.state.balls[i];
        ball.position = positions[i];
        ball.velocity = Offset.zero;
        ball.life = 1000;
        match.setTestBallPinned(ball, true);
      }
      final p = match.powerUps!;
      p.pickUp(
        match.state.balls.first,
        FieldPowerUp(
          kind: PowerUpKind.rocketLauncher,
          position: Offset.zero,
          spawnStep: 0,
        ),
      );
      for (var i = 0; i < 120 && p.projectiles.isEmpty; i++) {
        match.tick(1 / 60);
      }
      final shot = p.projectiles.single;
      expect(shot.target, same(match.state.balls[2]));
      match.state.balls[2].isEliminated = true;
      match.tick(1 / 60);
      expect(shot.target, same(match.state.balls[3]));
    },
  );
  test(
    'priority round-trips, and omitted old preferences preserve native defaults',
    () {
      for (final kind in PowerUpKind.values) {
        final skill = SkillLibrary.defaults.builtIn(
          kind,
          PowerUpConfig.defaults,
        );
        expect(
          skill.resolvedOpponentPriority,
          kind == PowerUpKind.busterSword
              ? OpponentPriority.farthest
              : OpponentPriority.nearest,
        );
        expect(skill.toJson().containsKey('opponent_priority'), isFalse);
        for (final priority in OpponentPriority.values) {
          final changed = skill.copyWith(opponentPriority: priority);
          final library = SkillLibrary.defaults.withDefinition(
            changed,
            PowerUpConfig.defaults,
          );
          expect(
            library.toJson()['version'],
            SkillLibrary.opponentPriorityVersion,
          );
          expect(
            SkillLibrary.fromJson(
              library.toCompactJson(),
            ).builtIn(kind, PowerUpConfig.defaults).opponentPriority,
            priority,
          );
          expect(
            SkillLibrary.decodeReplay(
              library.encodeReplay()!,
            )!.builtIn(kind, PowerUpConfig.defaults).opponentPriority,
            priority,
          );
          expect(
            SkillLibrary.fromJson(
              library.toJson(),
            ).builtIn(kind, PowerUpConfig.defaults).opponentPriority,
            priority,
          );
        }
      }
    },
  );
  for (final priority in OpponentPriority.values) {
    for (final kind in [
      PowerUpKind.busterSword,
      PowerUpKind.lightningStrikes,
      PowerUpKind.ragingDemon,
      PowerUpKind.shadowClone,
      PowerUpKind.gremlin,
      PowerUpKind.tornado,
    ]) {
      test(
        '${kind.name} selects ${priority.name} using shared configuration',
        () {
          final skill = SkillLibrary.defaults
              .builtIn(kind, PowerUpConfig.defaults)
              .copyWith(opponentPriority: priority);
          final match = setup(
            SkillLibrary.defaults.withDefinition(skill, PowerUpConfig.defaults),
          );
          final p = match.powerUps!;
          final owner = match.state.balls.first;
          p.pickUp(
            owner,
            FieldPowerUp(
              kind: kind,
              skillId: skill.id,
              position: owner.position,
              spawnStep: 0,
            ),
          );
          final expected =
              match.state.balls[priority == OpponentPriority.nearest ? 1 : 2];
          if (kind == PowerUpKind.busterSword) {
            for (var i = 0; i < 120 && p.omnislashAttacks.isEmpty; i++) {
              match.tick(1 / 60);
            }
            expect(p.omnislashAttacks.single.target, same(expected));
          } else if (kind == PowerUpKind.gremlin) {
            expect(expected.gremlinShots, greaterThan(0));
          } else {
            final target = switch (kind) {
              PowerUpKind.lightningStrikes => p.lightningStrikes.single.target,
              PowerUpKind.ragingDemon => p.ragingDemonAttacks.single.target,
              PowerUpKind.shadowClone => p.shadowCloneAttacks.single.target,
              _ => p.tornadoes.single.target,
            };
            expect(target, same(expected));
          }
        },
      );
    }
  }
  test('dual wield guns keep independent near and far priorities', () {
    var library = SkillLibrary.defaults;
    for (final pair in [
      (PowerUpKind.pistol, OpponentPriority.nearest),
      (PowerUpKind.freeze, OpponentPriority.farthest),
    ]) {
      library = library.withDefinition(
        library
            .builtIn(pair.$1, PowerUpConfig.defaults)
            .copyWith(opponentPriority: pair.$2),
        PowerUpConfig.defaults,
      );
    }
    final match = setup(library);
    final p = match.powerUps!;
    final owner = match.state.balls.first;
    for (final kind in [PowerUpKind.pistol, PowerUpKind.freeze]) {
      p.pickUp(
        owner,
        FieldPowerUp(kind: kind, position: Offset.zero, spawnStep: 0),
      );
    }
    for (var i = 0; i < 120 && p.shots < 2; i++) {
      match.tick(1 / 60);
    }
    final pistol = p.projectiles.firstWhere(
      (shot) => shot.kind == PowerUpKind.pistol,
    );
    final freeze = p.projectiles.firstWhere(
      (shot) => shot.kind == PowerUpKind.freeze,
    );
    expect(pistol.velocity.dx, greaterThan(0));
    expect(freeze.velocity.dx, lessThan(0));
  });
}
