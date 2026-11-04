import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const balls = [
  CustomBall(
    id: 'owner',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.orange,
  ),
  CustomBall(
    id: 'target',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];
MatchSimulationController match(
  SkillLibrary library, {
  MatchMode mode = MatchMode.arsenal,
}) {
  final c = MatchSimulationController(
    balls,
    arenaRadius: 260,
    mode: mode,
    seed: 1,
    lookAhead: false,
    slowMotionLines: 0,
    automaticSpeedUp: false,
    powerUpKinds: {},
    customSkillIds: {},
    skillLibrary: library,
  );
  c.state.balls[0]
    ..position = const Offset(-100, 0)
    ..velocity = Offset.zero;
  c.state.balls[1]
    ..position = const Offset(100, 0)
    ..velocity = Offset.zero;
  return c;
}

void finish(MatchSimulationController c) {
  for (var i = 0; i < 600 && c.state.status != MatchStatus.finished; i++) {
    c.tick(1 / 60);
  }
  expect(c.state.status, MatchStatus.finished);
}

SkillDefinition variant(SkillLibrary library, String name, int tint) => library
    .duplicate(
      library.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults),
      name,
    )
    .copyWith(
      arsenalDamage: 300,
      projectileCount: 1,
      projectileSpeed: 2,
      range: 2,
      spriteTint: tint,
    );
void main() {
  test(
    'duplicate names retain the actual equipped skill and its tint after firing',
    () {
      var library = SkillLibrary.defaults;
      final first = variant(library, 'Same name', 0xffff0000);
      library = library.withDefinition(first, PowerUpConfig.defaults);
      final second = variant(library, 'Same name', 0xff00ff00);
      library = library.withDefinition(second, PowerUpConfig.defaults);
      final c = match(library);
      c.state.balls.first
        ..held = PowerUpKind.pistol
        ..heldSkillId = second.id;
      finish(c);
      expect(c.winningMove, 'Same name');
      expect(c.winningMoveIdentity!.sourceId, second.id);
      expect(c.winningSkill!.id, second.id);
      expect(c.winningSkill!.spriteTint, 0xff00ff00);
      expect(c.winningSkill!.arsenalDamage, 300);
      c.state.balls.first.removeWeapon(PowerUpKind.pistol);
      expect(c.winningSkill!.id, second.id);
    },
  );
  for (final delivery in ['hit', 'dot', 'delayed']) {
    test(
      'payload $delivery credits the firing definition rather than its payload or duplicate name',
      () {
        var library = SkillLibrary.defaults;
        var payload = variant(library, 'Payload', 0xffff0000);
        if (delivery == 'dot') {
          payload = payload.copyWith(
            effectType: SkillEffectType.damageOverTime,
            durationSeconds: .5,
            tickIntervalSeconds: .1,
            dotArsenalDamage: 300,
          );
        }
        if (delivery == 'delayed') {
          payload = payload.copyWith(
            effectSteps: const [
              SkillEffectStep(
                type: SkillEffectType.damage,
                delaySeconds: .1,
                damage: 300,
              ),
            ],
          );
        }
        library = library.withDefinition(payload, PowerUpConfig.defaults);
        final wrong = variant(library, 'Twin launcher', 0xffff0000);
        library = library.withDefinition(wrong, PowerUpConfig.defaults);
        final issuer = variant(
          library,
          'Twin launcher',
          0xff00ff00,
        ).copyWith(payloadSkillId: payload.id);
        library = library.withDefinition(issuer, PowerUpConfig.defaults);
        final c = match(library);
        c.state.balls.first
          ..held = PowerUpKind.pistol
          ..heldSkillId = issuer.id;
        finish(c);
        expect(c.winningMoveIdentity!.sourceId, issuer.id);
        expect(c.winningSkill!.payloadSkillId, payload.id);
        expect(c.winningSkill!.spriteTint, 0xff00ff00);
      },
    );
  }
  test(
    'native weapon overrides retain their built-in identity and presentation',
    () {
      var library = SkillLibrary.defaults;
      final builtin = library
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(
            name: 'Renamed pistol',
            arsenalDamage: 300,
            spriteTint: 0xffccaa00,
          );
      library = library.withDefinition(builtin, PowerUpConfig.defaults);
      final c = match(library);
      c.state.balls.first.held = PowerUpKind.pistol;
      finish(c);
      expect(c.winningMove, 'Renamed pistol');
      expect(c.winningSkill!.id, builtin.id);
      expect(c.winningSkill!.spriteTint, 0xffccaa00);
    },
  );
  test('All-Out winning cuts preserve the exact custom definition', () {
    var library = SkillLibrary.defaults;
    final skill = variant(library, 'Cut', 0xff55aa22);
    library = library.withDefinition(skill, PowerUpConfig.defaults);
    final c = match(library, mode: MatchMode.allOut), victimIndex = 1;
    final victim = c.state.balls[victimIndex];
    c.cutThreads(
      victim,
      victim.fanLines.length,
      move: skill.name,
      moveSkill: skill,
      attacker: c.state.balls.first,
    );
    finish(c);
    expect(c.winningSkill!.id, skill.id);
  });
  test('native projectile thread cuts forward the captured skill identity', () {
    var library = SkillLibrary.defaults;
    final skill = library
        .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
        .copyWith(name: 'Thread pistol', allOutDamage: 100);
    library = library.withDefinition(skill, PowerUpConfig.defaults);
    final c = match(library, mode: MatchMode.allOut);
    c.state.balls.first.held = PowerUpKind.pistol;
    finish(c);
    expect(c.winningMove, skill.name);
    expect(c.winningSkill?.id, skill.id);
  });
  test(
    'environment and body hits clear earlier skill attribution, even with colliding labels',
    () {
      final skill = variant(SkillLibrary.defaults, 'Laser Gate', 0xff00ff00);
      for (final environment in [true, false]) {
        final c = match(SkillLibrary.defaults);
        final victim = c.state.balls.last;
        c.damage(victim, 1, move: skill.name, moveSkill: skill);
        c.damage(
          victim,
          500,
          move: environment ? 'Laser Gate' : 'Collision',
          moveSourceId: environment ? 'arena.laser-gate' : null,
        );
        finish(c);
        expect(c.winningSkill, isNull);
        expect(
          c.winningMoveIdentity!.sourceId,
          environment ? 'arena.laser-gate' : 'event.collision',
        );
      }
    },
  );
}
