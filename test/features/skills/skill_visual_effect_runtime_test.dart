import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/core/sprites/sprite_atlas.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_effect_renderer.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

class _Canvas extends Fake implements Canvas {
  final draws = <(ui.Image, Rect)>[];
  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(0, 0, 720, 480);
  @override
  void drawImageRect(ui.Image image, Rect source, Rect target, Paint paint) =>
      draws.add((image, target));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _balls = [
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
];
const _hit = EffectDefinition(
  id: 'hit',
  name: 'Hit',
  spriteId: 'qa.hit',
  durationSeconds: 1.2,
);
const _blast = EffectDefinition(
  id: 'blast',
  name: 'Blast',
  spriteId: 'qa.blast',
  durationSeconds: 2,
);

SkillLibrary library({bool bindings = true}) {
  final base = SkillLibrary.defaults.withEffect(_hit).withEffect(_blast);
  return base.withDefinition(
    base
        .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
        .copyWith(
          visualBindings: bindings
              ? const {
                  SkillVisualRole.casting: SkillVisualBinding(effectId: 'hit'),
                  SkillVisualRole.impact: SkillVisualBinding(effectId: 'hit'),
                  SkillVisualRole.explosion: SkillVisualBinding(
                    effectId: 'blast',
                  ),
                }
              : {},
        ),
    PowerUpConfig.defaults,
  );
}

MatchSimulationController match({bool bindings = true}) {
  final result = MatchSimulationController(
    _balls,
    arenaRadius: 180,
    mode: MatchMode.arsenal,
    seed: 42,
    automaticSpeedUp: false,
    lookAhead: false,
    skillLibrary: library(bindings: bindings),
  );
  result.powerUps!.automaticSpawning = false;
  result.state.balls[0]
    ..position = const Offset(-60, 0)
    ..velocity = Offset.zero;
  result.state.balls[1]
    ..position = const Offset(60, 0)
    ..velocity = Offset.zero;
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await TestWidgetsFlutterBinding.instance.runAsync(() async {
      for (final entry in {
        'qa.hit': Colors.red,
        'qa.blast': Colors.blue,
      }.entries) {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 16, 16),
          Paint()..color = entry.value,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(16, 16);
        await SpriteRegistry.registerDrawn(entry.key, image, output: 16);
        image.dispose();
        picture.dispose();
      }
    });
  });

  test(
    'non-interactive finisher uses the same distinct hit and explosion recipes',
    () {
      final c = match();
      final original = c.skillLibrary.builtIn(PowerUpKind.pistol, c.tuning);
      final grenade = c.skillLibrary
          .builtIn(PowerUpKind.grenade, c.tuning)
          .copyWith(visualBindings: original.visualBindings);
      final canvas = _Canvas();
      HarpoonCinematic.paintFrame(
        canvas,
        const Size(720, 480),
        _balls[0],
        _balls[1],
        'Grenade',
        .77,
        skill: grenade,
        library: c.skillLibrary,
      );
      expect(
        canvas.draws.where(
          (draw) => identical(draw.$1, SpriteRegistry.frame('qa.hit')),
        ),
        hasLength(1),
      );
      expect(
        canvas.draws.where(
          (draw) => identical(draw.$1, SpriteRegistry.frame('qa.blast')),
        ),
        hasLength(1),
      );
    },
  );

  test(
    'arena draws different direct-hit and explosion bindings through the shared renderer',
    () {
      final c = match();
      final p = c.powerUps!;
      p.weaponImpacts.add(
        WeaponImpact(
          position: Offset.zero,
          strength: 0,
          kind: PowerUpKind.pistol,
          skillId: 'builtin.pistol',
        ),
      );
      p.explosions.add(
        Explosion(
          position: Offset.zero,
          radius: 20,
          kind: PowerUpKind.pistol,
          skillId: 'builtin.pistol',
        ),
      );
      final hitCanvas = _Canvas();
      PowerUpPainter.paintImpacts(hitCanvas, c.state);
      expect(hitCanvas.draws.single.$1, same(SpriteRegistry.frame('qa.hit')));
      final blastCanvas = _Canvas();
      PowerUpPainter.paint(blastCanvas, c.state, 180);
      expect(
        blastCanvas.draws.single.$1,
        same(SpriteRegistry.frame('qa.blast')),
      );
      expect(blastCanvas.draws.single.$2.width, 40);
      final resolved = c.skillLibrary.resolveVisual(
        c.skillLibrary.builtIn(PowerUpKind.pistol, c.tuning),
        SkillVisualRole.explosion,
      )!;
      final sharedCanvas = _Canvas();
      expect(
        SkillEffectRenderer.paint(
          sharedCanvas,
          resolved,
          Offset.zero,
          20,
          0,
          120,
        ),
        isTrue,
      );
      expect(sharedCanvas.draws.single.$2, blastCanvas.draws.single.$2);
    },
  );

  test(
    'shared playback distinguishes fitted once, natural loop and hold-last',
    () async {
      await TestWidgetsFlutterBinding.instance.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 16, 16),
          Paint()..color = Colors.red,
        );
        canvas.drawRect(
          const Rect.fromLTWH(16, 0, 16, 16),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(32, 16);
        await SpriteRegistry.register(
          const SpriteAtlas(
            sheet: 'test',
            sprites: {
              'spin': SpriteDef(
                id: 'spin',
                frames: [
                  Rect.fromLTWH(0, 0, 16, 16),
                  Rect.fromLTWH(16, 0, 16, 16),
                ],
                output: 16,
                padding: 0,
                stepsPerFrame: 2,
              ),
            },
          ),
          image,
          idPrefix: 'qa.playback',
        );
        image.dispose();
        picture.dispose();
      });
      ResolvedSkillEffect effect(EffectPlayback playback) =>
          ResolvedSkillEffect(
            spriteId: 'qa.playback.spin',
            scale: 1,
            opacity: 1,
            tint: 0xffffffff,
            playback: playback,
          );
      final first = SpriteRegistry.frame('qa.playback.spin', 0);
      final last = SpriteRegistry.frame('qa.playback.spin', 1);
      expect(
        SkillEffectRenderer.frame(effect(EffectPlayback.once), 3, 20),
        same(first),
      );
      expect(
        SkillEffectRenderer.frame(effect(EffectPlayback.once), 19, 20),
        same(last),
      );
      expect(
        SkillEffectRenderer.frame(effect(EffectPlayback.loop), 3, 20),
        same(last),
      );
      expect(
        SkillEffectRenderer.frame(effect(EffectPlayback.loop), 4, 20),
        same(first),
      );
      expect(
        SkillEffectRenderer.frame(effect(EffectPlayback.holdLast), 10, 20),
        same(last),
      );
    },
  );

  test(
    'bound visual lifetimes outlast the old hit flash without extending screen-shake timing',
    () {
      final c = match();
      final p = c.powerUps!;
      final hit = WeaponImpact(
        position: Offset.zero,
        strength: 0,
        kind: PowerUpKind.pistol,
        skillId: 'builtin.pistol',
      );
      final blast = Explosion(
        position: Offset.zero,
        radius: 20,
        kind: PowerUpKind.pistol,
        skillId: 'builtin.pistol',
      );
      p.weaponImpacts.add(hit);
      p.explosions.add(blast);
      for (var i = 0; i < 30; i++) {
        c.tick(1 / 60);
      }
      expect(p.weaponImpacts, contains(hit));
      expect(p.explosions, contains(blast));
      expect(p.impactVisualSteps(hit), 72);
      expect(p.explosionVisualSteps(blast), 120);
      for (var i = 0; i < 100; i++) {
        c.tick(1 / 60);
      }
      expect(p.weaponImpacts, isNot(contains(hit)));
      expect(p.explosions, isNot(contains(blast)));
    },
  );

  test(
    'visual bindings do not change native shot damage or seeded movement',
    () {
      final original = match(bindings: false);
      final bound = match();
      for (final c in [original, bound]) {
        final owner = c.state.balls.first;
        c.powerUps!.pickUp(
          owner,
          FieldPowerUp(
            kind: PowerUpKind.pistol,
            position: owner.position,
            spawnStep: 0,
            skillId: 'builtin.pistol',
          ),
        );
        owner.aimLeft = 1;
        owner.aimTarget = c.state.balls.last;
        for (var i = 0; i < 180; i++) {
          c.tick(1 / 60);
        }
        expect(c.powerUps!.hits, greaterThan(0));
      }
      for (var i = 0; i < 2; i++) {
        expect(bound.state.balls[i].life, original.state.balls[i].life);
        expect(bound.state.balls[i].position, original.state.balls[i].position);
        expect(bound.state.balls[i].velocity, original.state.balls[i].velocity);
      }
    },
  );
}
