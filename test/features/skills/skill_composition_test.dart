import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

const _tuning = PowerUpConfig.defaults;

/// A saved custom projectile skill to be fired by others: returns, bigger, gold, its own damage.
SkillDefinition _boomMerang() => SkillLibrary.defaults
    .create('Boom-merang', PowerUpKind.boomerang)
    .copyWith(
      returnsToOrigin: true,
      projectileSize: 2,
      spriteTint: 0xFFFFD700,
      arsenalDamage: 33,
      knockback: 3,
      soundCue: 'slash',
    );

/// Any skill can look like any weapon and fire any projectile skill.
SkillDefinition _combo(String name, PowerUpKind carrier, String fires, {PowerUpKind? looksLike, int count = 3}) =>
    SkillLibrary.defaults
        .create(name, carrier)
        .copyWith(artworkKind: looksLike, payloadSkillId: fires, projectileCount: count, spreadDegrees: 20);

SkillLibrary _library(List<SkillDefinition> skills) {
  var library = SkillLibrary.defaults;
  for (final skill in skills) {
    library = library.withDefinition(skill, _tuning);
  }
  return library;
}

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

MatchSimulationController _match(SkillLibrary library) {
  final c = MatchSimulationController(
    _balls,
    arenaRadius: 260,
    seed: 1,
    layoutRotation: 0,
    mode: MatchMode.arsenal,
    lookAhead: false,
    skillLibrary: library,
  );
  final [a, b] = c.state.balls;
  for (final ball in [a, b]) {
    ball.velocity = Offset.zero;
  }
  a.position = const Offset(-100, 0);
  b.position = const Offset(100, 0);
  return c;
}

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps; i++) {
    c.tick(1 / 60);
  }
}

void _equip(SimulationBall ball, SkillDefinition skill) =>
    ball.equipWeapon(skill.baseKind, skillId: skill.id, dualWield: false);

void main() {
  group('model', () {
    test('look and fired skill save, load and clear', () {
      final boom = _boomMerang();
      final combo = _combo('Knife Volley', PowerUpKind.knife, boom.id, looksLike: PowerUpKind.knife);
      final back = SkillDefinition.fromJson(combo.toJson())!;
      expect(back.artworkKind, PowerUpKind.knife);
      expect(back.payloadSkillId, boom.id);
      expect(back.projectileCount, 3);
      expect(back.displayKind, PowerUpKind.knife);

      final cleared = back.copyWith(artworkKind: null, payloadSkillId: null);
      expect(cleared.artworkKind, isNull);
      expect(cleared.payloadSkillId, isNull);
      expect(cleared.displayKind, cleared.baseKind);
      expect(SkillDefinition.fromJson(cleared.toJson())!.payloadSkillId, isNull);
    });

    test('any combination resolves to the fired skill; chains follow to the last one', () {
      final boom = _boomMerang();
      final relay = _combo('Relay', PowerUpKind.pistol, boom.id, count: 2);
      final top = _combo('Top', PowerUpKind.sword, relay.id, looksLike: PowerUpKind.mirror);
      final builtinShot = _combo('Bow Burst', PowerUpKind.pistol, 'builtin.bow', count: 5);
      final library = _library([boom, relay, top, builtinShot]);

      expect(library.payloadProblem(top, _tuning), isNull);
      expect(library.resolvePayload(top, _tuning)!.id, boom.id);
      expect(library.resolvePayload(relay, _tuning)!.toJson(), boom.toJson());

      final bow = library.resolvePayload(builtinShot, _tuning)!;
      expect(bow.id, 'builtin.bow');
      expect(bow.delivery, SkillDelivery.projectile);
      expect(bow.arsenalDamage, _tuning.arenaDamage(PowerUpKind.bow));

      expect(library.resolvePayload(boom, _tuning), isNull, reason: 'fires its own projectile');
    });

    test('broken references explain what is wrong and fall back to the own projectile', () {
      final boom = _boomMerang();
      final apple = SkillLibrary.defaults.create('Snack', PowerUpKind.apple);
      final self = _combo('Selfie', PowerUpKind.pistol, 'custom.selfie');
      final missing = _combo('Ghost Shot', PowerUpKind.pistol, 'custom.nothing-here');
      final wrong = _combo('Fruit Gun', PowerUpKind.pistol, apple.id);
      final loopA = _combo('Loop A', PowerUpKind.pistol, 'custom.loop-b');
      final loopB = _combo('Loop B', PowerUpKind.pistol, 'custom.loop-a');
      final notAimed = apple.copyWith(payloadSkillId: boom.id);
      final library = _library([boom, apple, self, missing, wrong, loopA, loopB, notAimed]);
      final saved = {for (final s in library.custom) s.name: s};

      expect(saved['Selfie']!.id, 'custom.selfie');
      expect(library.payloadProblem(saved['Selfie']!, _tuning), "A skill can't fire itself.");
      expect(library.payloadProblem(saved['Ghost Shot']!, _tuning), contains('no longer exists'));
      expect(library.payloadProblem(saved['Fruit Gun']!, _tuning), 'Snack does not fire projectiles.');
      expect(library.payloadProblem(saved['Loop A']!, _tuning), startsWith('Loop: Loop A → Loop B → Loop A'));
      expect(library.payloadProblem(library.byId(apple.id, _tuning)!, _tuning), contains('aimed weapon'));
      for (final name in ['Selfie', 'Ghost Shot', 'Fruit Gun', 'Loop A']) {
        expect(library.resolvePayload(saved[name]!, _tuning), isNull, reason: name);
      }
    });

    test('the pickers offer every projectile skill but the skill itself', () {
      final boom = _boomMerang();
      final combo = _combo('Knife Volley', PowerUpKind.knife, boom.id);
      final library = _library([boom, combo]);
      final ids = library.payloadCandidates(combo, _tuning).map((s) => s.id).toSet();
      expect(ids, containsAll([boom.id, 'builtin.pistol', 'builtin.boomerang', 'builtin.bow']));
      expect(ids, isNot(contains(combo.id)));
      expect(ids, isNot(contains('builtin.apple')));
      expect(ids, isNot(contains('builtin.flamethrower')));
    });

    test('combining never changes the originals; replays keep the combination', () {
      final boom = _boomMerang();
      final combo = _combo('Knife Volley', PowerUpKind.knife, boom.id, looksLike: PowerUpKind.knife);
      final library = _library([boom, combo]);
      expect(library.byId(boom.id, _tuning)!.toJson(), boom.toJson());
      expect(library.builtIn(PowerUpKind.knife, _tuning).payloadSkillId, isNull);
      expect(library.builtIn(PowerUpKind.knife, _tuning).artworkKind, isNull);

      final replayed = SkillLibrary.decodeReplay(library.encodeReplay()!)!;
      final again = replayed.byId(combo.id, _tuning)!;
      expect(again.artworkKind, PowerUpKind.knife);
      expect(replayed.resolvePayload(again, _tuning)!.toJson(), boom.toJson());
    });
  });

  group('match', () {
    test('a Knife-looking skill fires three Boom-merangs that keep all their own behavior', () {
      final boom = _boomMerang();
      final combo = _combo('Knife Volley', PowerUpKind.knife, boom.id, looksLike: PowerUpKind.knife);
      final c = _match(_library([boom, combo]));
      final [a, _] = c.state.balls;
      _equip(a, combo);
      final p = c.powerUps!;
      expect(p.visualSkill(PowerUpKind.knife, skillId: combo.id).displayKind, PowerUpKind.knife);

      for (var i = 0; i < 120 && p.projectiles.isEmpty; i++) {
        _run(c, 1);
      }
      final shots = p.projectiles.toList();
      expect(shots, hasLength(3));
      for (final shot in shots) {
        expect(shot.kind, PowerUpKind.boomerang);
        expect(p.projectileSkill(shot)!.toJson(), boom.toJson());
        expect(p.projectileIssuer(shot)!.id, combo.id);
        expect(shot.renderScale, 2);
        expect(shot.returnTo, isNotNull, reason: 'returns like the Boom-merang');
        expect(p.artworkTint(shot.kind, projectile: shot), 0xFFFFD700);
      }
    });

    test("payload hits deal the fired skill's damage and credit the firing skill", () {
      final boom = _boomMerang();
      final combo = _combo('Knife Volley', PowerUpKind.knife, boom.id, looksLike: PowerUpKind.knife, count: 1);
      final c = _match(_library([boom, combo]));
      final [a, b] = c.state.balls;
      _equip(a, combo);
      b.life = 20;
      for (var i = 0; i < 400 && c.state.winnerId == null; i++) {
        _run(c, 1);
        a.velocity = Offset.zero;
        b.velocity = Offset.zero;
      }
      expect(c.state.winnerId, a.config.id);
      expect(c.winningMove, 'Knife Volley');
    });

    test('different combinations fire at the same time, each with its own payload', () {
      final boom = _boomMerang();
      final knifeVolley = _combo('Knife Volley', PowerUpKind.knife, boom.id, looksLike: PowerUpKind.knife);
      final bowBurst = _combo('Bow Burst', PowerUpKind.pistol, 'builtin.bow', count: 2);
      final c = _match(_library([boom, knifeVolley, bowBurst]));
      final [a, b] = c.state.balls;
      _equip(a, knifeVolley);
      _equip(b, bowBurst);
      final p = c.powerUps!;
      for (var i = 0; i < 120 && p.projectiles.length < 5; i++) {
        _run(c, 1);
      }
      final fromA = p.projectiles.where((s) => identical(s.owner, a)).toList();
      final fromB = p.projectiles.where((s) => identical(s.owner, b)).toList();
      expect(fromA, hasLength(3));
      expect(fromB, hasLength(2));
      expect(fromA.every((s) => p.projectileSkill(s)!.id == boom.id), isTrue);
      expect(fromB.every((s) => p.projectileSkill(s)!.id == 'builtin.bow' && s.kind == PowerUpKind.bow), isTrue);
    });

    test('a broken reference fires the skill\'s own projectile instead', () {
      final combo = _combo('Lost Shot', PowerUpKind.pistol, 'custom.gone', count: 2);
      final c = _match(_library([combo]));
      final [a, _] = c.state.balls;
      _equip(a, combo);
      final p = c.powerUps!;
      for (var i = 0; i < 120 && p.projectiles.isEmpty; i++) {
        _run(c, 1);
      }
      expect(p.projectiles, isNotEmpty);
      expect(p.projectiles.every((s) => p.projectileSkill(s)!.id == combo.id), isTrue);
    });
  });
}
