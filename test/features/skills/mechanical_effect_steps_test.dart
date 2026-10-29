import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/mechanical_effects_editor.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'visual_authoring_test.dart' as fixtures;

SkillDefinition sequence(List<SkillEffectStep> steps) => SkillLibrary.defaults
    .create('Sequence', PowerUpKind.pistol)
    .copyWith(
      delivery: SkillDelivery.instant,
      knockback: 0,
      effectSteps: steps,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'composed carrier artwork does not force hook pulls, rocket blasts or prism splits',
    () {
      for (final kind in [
        PowerUpKind.hook,
        PowerUpKind.rocketLauncher,
        PowerUpKind.prismLaser,
      ]) {
        final original =
            sequence(const [
              SkillEffectStep(type: SkillEffectType.damage, damage: 4),
            ]).copyWith(
              delivery: SkillDelivery.projectile,
              projectileSpeed: 2,
              maxBounces: 1,
            );
        final skill = SkillDefinition.fromJson({
          ...original.toJson(),
          'base': kind.name,
        })!;
        final m = fixtures.match(skill),
            a = m.state.balls.first,
            b = m.state.balls.last;
        m.powerUps!.activateTestSkill(a, skill, b);
        if (kind == PowerUpKind.prismLaser) b.position = const Offset(0, 120);
        for (var i = 0; i < 45; i++) {
          m.tick(1 / 60);
        }
        if (kind == PowerUpKind.prismLaser) {
          expect(m.powerUps!.projectiles.length, lessThanOrEqualTo(1));
        } else {
          expect(b.life, 96);
          expect(m.powerUps!.pulls, isEmpty);
          expect(m.powerUps!.explosions, isEmpty);
        }
      }
    },
  );

  test(
    'homing and returning ordered projectiles keep their configured speed',
    () {
      final skill =
          sequence(const [
            SkillEffectStep(type: SkillEffectType.damage, damage: 1),
          ]).copyWith(
            delivery: SkillDelivery.projectile,
            homing: true,
            returnsToOrigin: true,
            projectileSpeed: 3,
          );
      final m = fixtures.match(skill),
          a = m.state.balls.first,
          b = m.state.balls.last;
      m.powerUps!.activateTestSkill(a, skill, b);
      m.tick(1 / 60);
      expect(
        m.powerUps!.projectiles.single.velocity.distance,
        closeTo(540, .001),
      );
      m.powerUps!.projectiles.single
        ..position = const Offset(80, 0)
        ..returning = true;
      m.tick(1 / 60);
      expect(m.powerUps!.projectiles, hasLength(1));
      expect(
        m.powerUps!.projectiles.single.velocity.distance,
        closeTo(540, .001),
      );
    },
  );

  test(
    'projectile artwork scale is independent of physical reach for ordered steps',
    () {
      final damage = sequence(const [
        SkillEffectStep(type: SkillEffectType.damage, damage: 6),
      ]).copyWith(delivery: SkillDelivery.projectile, projectileSpeed: 2);
      for (final scale in [1.0, 4.0]) {
        final skill = damage.copyWith(projectileSize: scale);
        final m = fixtures.match(skill),
            a = m.state.balls.first,
            b = m.state.balls.last;
        m.powerUps!.activateTestSkill(a, skill, b);
        b.position = Offset(50, b.radius + a.radius * .3);
        for (var i = 0; i < 40; i++) {
          m.tick(1 / 60);
        }
        expect(b.life, 100);
      }
      final wider = damage.copyWith(projectileHitRadius: 1);
      final m = fixtures.match(wider),
          a = m.state.balls.first,
          b = m.state.balls.last;
      m.powerUps!.activateTestSkill(a, wider, b);
      b.position = Offset(50, b.radius + a.radius * .3);
      for (var i = 0; i < 40; i++) {
        m.tick(1 / 60);
      }
      expect(b.life, 94);
    },
  );

  test(
    'self healing happens once for an all-opponent activation, retargeting is live',
    () {
      final skill = sequence(const [
        SkillEffectStep(type: SkillEffectType.damage, damage: 4),
        SkillEffectStep(
          type: SkillEffectType.heal,
          target: EffectStepTarget.self,
          healing: 5,
        ),
        SkillEffectStep(
          type: SkillEffectType.damage,
          target: EffectStepTarget.nearestOpponent,
          delaySeconds: .2,
          damage: 7,
        ),
      ]).copyWith(targeting: SkillTargeting.allOpponents);
      final m = MatchSimulationController(
        [
          ...fixtures.balls,
          const CustomBall(
            id: 'c',
            name: 'C',
            primaryColor: Colors.green,
            glowColor: Colors.green,
          ),
        ],
        mode: MatchMode.arsenal,
        arenaRadius: 180,
        seed: 1,
        lookAhead: false,
        automaticSpeedUp: false,
        skillLibrary: SkillLibrary.defaults.withDefinition(
          skill,
          PowerUpConfig.defaults,
        ),
      );
      m.powerUps!.automaticSpawning = false;
      for (var i = 0; i < 3; i++) {
        m.state.balls[i]
          ..position = Offset(-100 + i * 80, 0)
          ..velocity = Offset.zero;
      }
      final a = m.state.balls[0], b = m.state.balls[1], c = m.state.balls[2];
      a.life = 80;
      m.powerUps!.activateTestSkill(a, skill, b);
      expect(a.life, 85);
      expect(b.life, 91);
      expect(c.life, 91);
      b.position = const Offset(80, 80);
      c.position = const Offset(-20, 30);
      for (var i = 0; i < 12; i++) {
        m.tick(1 / 60);
      }
      expect(b.life, 91);
      expect(c.life, 75.25);
    },
  );

  test('returning projectile applies all steps once per contact session', () {
    final skill =
        sequence(const [
          SkillEffectStep(type: SkillEffectType.damage, damage: 4),
          SkillEffectStep(type: SkillEffectType.damage, damage: 2),
        ]).copyWith(
          delivery: SkillDelivery.projectile,
          returnsToOrigin: true,
          projectileSpeed: 2,
        );
    final m = fixtures.match(skill),
        a = m.state.balls.first,
        b = m.state.balls.last;
    m.powerUps!.activateTestSkill(a, skill, b);
    for (var i = 0; i < 50; i++) {
      m.tick(1 / 60);
    }
    expect(b.life, 94);
    expect(m.powerUps!.projectiles, isEmpty);
  });

  test(
    'projectile impact explosion respects start delay and step parameters',
    () {
      final skill =
          sequence(const [
            SkillEffectStep(type: SkillEffectType.damage, damage: 4),
            SkillEffectStep(
              type: SkillEffectType.damage,
              damage: 2,
              delaySeconds: .1,
            ),
          ]).copyWith(
            delivery: SkillDelivery.projectile,
            projectileSpeed: 2,
            explodesOnImpact: true,
            startDelaySeconds: .2,
            repeatCount: 2,
            repeatIntervalSeconds: .3,
          );
      final m = fixtures.match(skill),
          a = m.state.balls.first,
          b = m.state.balls.last;
      m.powerUps!.activateTestSkill(a, skill, b);
      for (var i = 0; i < 15; i++) {
        m.tick(1 / 60);
      }
      expect(b.life, 100);
      for (var i = 0; i < 55; i++) {
        m.tick(1 / 60);
      }
      expect(b.life, 88);
    },
  );

  test('changing art does not change mechanical outcome', () {
    final base = sequence(const [
      SkillEffectStep(type: SkillEffectType.damage, damage: 3),
      SkillEffectStep(
        type: SkillEffectType.damageOverTime,
        damage: 2,
        tickIntervalSeconds: .1,
        durationSeconds: .2,
      ),
    ]);
    final changed = base.copyWith(
      iconSpriteId: 'missing.icon',
      impactSpriteId: 'missing.impact',
      effectDisplayScale: 3,
      projectileSize: 4,
      spriteTint: 0xffffcc00,
    );
    final first = fixtures.match(base), second = fixtures.match(changed);
    for (final entry in [(first, base), (second, changed)]) {
      entry.$1.powerUps!.activateTestSkill(
        entry.$1.state.balls.first,
        entry.$2,
        entry.$1.state.balls.last,
      );
      for (var i = 0; i < 20; i++) {
        entry.$1.tick(1 / 60);
      }
    }
    expect(first.state.balls.last.life, second.state.balls.last.life);
    expect(first.state.balls.last.position, second.state.balls.last.position);
    expect(first.state.balls.last.velocity, second.state.balls.last.velocity);
  });

  testWidgets(
    'ordered steps edited in Skill Management save and execute after reload',
    (tester) async {
      final original = sequence(const [
        SkillEffectStep(type: SkillEffectType.damage, damage: 4),
      ]);
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults.withDefinition(
              original,
              PowerUpConfig.defaults,
            ),
            tuning: PowerUpConfig.defaults,
            onSave: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        original.name,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, original.name));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit-mechanical-steps')),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('edit-mechanical-steps')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('step-damage')), '9');
      await tester.tap(find.text('Use steps'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final read = SkillLibrary.importJson(
        jsonEncode(saved!.library.toJson()),
      ).custom.single;
      expect(read.effectSteps.single.damage, 9);
      final m = fixtures.match(read);
      m.powerUps!.activateTestSkill(
        m.state.balls.first,
        read,
        m.state.balls.last,
      );
      expect(m.state.balls.last.life, 91);
    },
  );

  test(
    'ordered steps save in full/compact, duplicate and replay snapshots',
    () {
      final skill = sequence(const [
        SkillEffectStep(
          type: SkillEffectType.damage,
          damage: 7,
          threadDamage: 2,
        ),
        SkillEffectStep(
          type: SkillEffectType.heal,
          target: EffectStepTarget.self,
          healing: 3,
        ),
        SkillEffectStep(
          type: SkillEffectType.stun,
          delaySeconds: .2,
          durationSeconds: .4,
        ),
      ]);
      final library = SkillLibrary.defaults.withDefinition(
        skill,
        PowerUpConfig.defaults,
      );
      expect(library.toJson()['version'], 12);
      expect(library.toCompactJson()['version'], 13);
      for (final json in [library.toJson(), library.toCompactJson()]) {
        final restored = SkillLibrary.importJson(
          jsonEncode(json),
        ).custom.single;
        expect(
          restored.effectSteps.map((s) => s.toJson()),
          skill.effectSteps.map((s) => s.toJson()),
        );
        expect(restored.canDamage, isTrue);
        expect(restored.canHeal, isTrue);
      }
      expect(library.duplicate(skill, 'Another').effectSteps.length, 3);
      final replay = SkillLibrary.decodeReplay(library.encodeReplay()!)!;
      expect(replay.custom.single.effectSteps.length, 3);
      expect(SkillLibrary.defaults.toJson()['version'], 2);
      expect(SkillLibrary.defaults.toCompactJson()['version'], 3);
    },
  );

  test(
    'reject invalid numbers, recursive fields, unknown targets and ninth step',
    () {
      for (final raw in [
        {'type': 'damage', 'damage': double.nan},
        {'type': 'damage', 'delay': -1},
        {'type': 'damage', 'threads': 1.2},
        {'type': 'damage', 'repeat': 100000},
        {'type': 'damage', 'target': 'unknown'},
        {'type': 'damageOverTime', 'tick': 0},
      ]) {
        expect(() => SkillEffectStep.fromJson(raw), throwsFormatException);
      }
      expect(
        () => sequence(
          List.filled(9, const SkillEffectStep(type: SkillEffectType.damage)),
        ).validated(),
        throwsFormatException,
      );
    },
  );

  test(
    'three ordered operations use independent damage, self heal and stun',
    () {
      final skill = sequence(const [
        SkillEffectStep(type: SkillEffectType.damage, damage: 7),
        SkillEffectStep(
          type: SkillEffectType.heal,
          target: EffectStepTarget.self,
          healing: 3,
        ),
        SkillEffectStep(type: SkillEffectType.stun, durationSeconds: .4),
      ]);
      final m = fixtures.match(skill),
          a = m.state.balls.first,
          b = m.state.balls.last;
      a.life = 80;
      m.powerUps!.activateTestSkill(a, skill, b);
      expect(a.life, 83);
      expect(b.life, 93);
      expect(b.stunnedLeft, 24);
      expect(b.velocity, Offset.zero);
    },
  );

  test(
    'equal-time steps run in order, delayed target is resolved at execution',
    () {
      final skill = sequence(const [
        SkillEffectStep(type: SkillEffectType.heal, healing: 5),
        SkillEffectStep(type: SkillEffectType.damage, damage: 10),
        SkillEffectStep(
          type: SkillEffectType.damage,
          target: EffectStepTarget.nearestOpponent,
          delaySeconds: .2,
          damage: 3,
        ),
      ]);
      final m = fixtures.match(skill),
          a = m.state.balls.first,
          b = m.state.balls.last;
      b.life = PowerUpTuning.arenaMaxLife;
      m.powerUps!.activateTestSkill(a, skill, b);
      expect(
        b.life,
        140,
      ); // heal at max, then damage; reverse order would be 145.
      for (var i = 0; i < 11; i++) {
        m.tick(1 / 60);
      }
      expect(b.life, 140);
      m.tick(1 / 60);
      expect(b.life, 137);
    },
  );

  test(
    'delayed steps cancel when caster dies or either participant respawns',
    () {
      for (final reset in [false, true]) {
        final skill = sequence(const [
          SkillEffectStep(
            type: SkillEffectType.damage,
            damage: 20,
            delaySeconds: .2,
          ),
        ]);
        final m = fixtures.match(skill),
            a = m.state.balls.first,
            b = m.state.balls.last;
        m.powerUps!.activateTestSkill(a, skill, b);
        if (reset) {
          m.powerUps!.resetForRespawn(b);
        } else {
          a.life = 0;
        }
        for (var i = 0; i < 20; i++) {
          m.powerUps!.step();
        }
        expect(b.life, 100);
        expect(m.powerUps!.activeCustomEffectCount, 0);
      }
    },
  );

  test('different DoT steps keep their own damage, tick and duration', () {
    final skill = sequence(const [
      SkillEffectStep(
        type: SkillEffectType.damageOverTime,
        damage: 2,
        durationSeconds: .2,
        tickIntervalSeconds: .1,
      ),
      SkillEffectStep(
        type: SkillEffectType.damageOverTime,
        damage: 5,
        durationSeconds: .3,
        tickIntervalSeconds: .1,
      ),
    ]);
    final m = fixtures.match(skill),
        a = m.state.balls.first,
        b = m.state.balls.last;
    m.powerUps!.activateTestSkill(a, skill, b);
    for (var i = 0; i < 18; i++) {
      m.tick(1 / 60);
    }
    expect(b.life, 81); // 2*2 + 5*3
    expect(m.powerUps!.activeCustomEffectCount, 0);
  });

  test('repeat chains repeat the sequence and respect the bounded queue', () {
    final skill = sequence(const [
      SkillEffectStep(type: SkillEffectType.damage, damage: 2),
      SkillEffectStep(
        type: SkillEffectType.damage,
        damage: 3,
        delaySeconds: .1,
      ),
    ]).copyWith(repeatCount: 2, repeatIntervalSeconds: .2);
    final m = fixtures.match(skill),
        a = m.state.balls.first,
        b = m.state.balls.last;
    m.powerUps!.activateTestSkill(a, skill, b);
    for (var i = 0; i < 20; i++) {
      m.tick(1 / 60);
    }
    expect(b.life, 90);
    final expensive = skill.copyWith(
      repeatCount: 1,
      effectSteps: List.filled(
        8,
        const SkillEffectStep(
          type: SkillEffectType.damage,
          delaySeconds: 10,
          damage: 0,
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      m.powerUps!.activateTestSkill(a, expensive, b);
    }
    expect(m.powerUps!.activeCustomEffectCount, lessThanOrEqualTo(256));
    expect(m.powerUps!.compositionLimitHits, greaterThan(0));
  });

  test(
    'step range, ghost immunity and explicit zero knockback are honored',
    () {
      final skill = sequence(const [
        SkillEffectStep(
          type: SkillEffectType.damage,
          damage: 4,
          targetRangeRatio: .1,
        ),
        SkillEffectStep(type: SkillEffectType.damage, damage: 2, knockback: 0),
      ]).copyWith(knockback: 20);
      final m = fixtures.match(skill),
          a = m.state.balls.first,
          b = m.state.balls.last;
      m.powerUps!.activateTestSkill(a, skill, b);
      expect(b.life, 98);
      expect(b.velocity, Offset.zero);
      b.ghostLeft = 60;
      m.powerUps!.activateTestSkill(a, skill, b);
      expect(b.life, 98);
    },
  );

  testWidgets(
    'phone step tabs preserve edits, reorder and validate without closing',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      List<SkillEffectStep>? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await MechanicalEffectsEditor.show(context, const [
                      SkillEffectStep(type: SkillEffectType.damage, damage: 7),
                      SkillEffectStep(
                        type: SkillEffectType.heal,
                        target: EffectStepTarget.self,
                        healing: 3,
                      ),
                    ]),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('step-damage')), '11');
      await tester.tap(find.text('2. Heal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('step-healing')), '6');
      await tester.tap(find.byTooltip('Move earlier'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('step-healing')))
            .controller!
            .text,
        '6',
      );
      await tester.enterText(find.byKey(const ValueKey('step-delay')), '-1');
      await tester.tap(find.text('Use steps'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 1: Effect step delay'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byKey(const ValueKey('step-delay')), '.2');
      await tester.tap(find.text('Use steps'));
      await tester.pumpAndSettle();
      expect(result!.first.type, SkillEffectType.heal);
      expect(result!.first.healing, 6);
      expect(result!.last.damage, 11);
      expect(tester.takeException(), isNull);
    },
  );
}
