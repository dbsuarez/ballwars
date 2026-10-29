import 'dart:ui' as ui;
import 'dart:math' as math;
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
  final translations = <Offset>[];
  final rotations = <double>[];
  final scales = <Offset>[];
  @override
  void translate(double x, double y) => translations.add(Offset(x, y));
  @override
  void rotate(double angle) => rotations.add(angle);
  @override
  void scale(double x, [double? y]) => scales.add(Offset(x, y ?? x));
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
  test(
    'native impact follows its target and explosion follows recorded direction',
    () {
      final base = library();
      final skill = base
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(
            visualBindings: const {
              SkillVisualRole.impact: SkillVisualBinding(
                effectId: 'hit',
                attachment: EffectAttachment.target,
              ),
              SkillVisualRole.explosion: SkillVisualBinding(
                effectId: 'blast',
                facing: EffectFacing.direction,
              ),
            },
          );
      final c = MatchSimulationController(
        _balls,
        arenaRadius: 180,
        mode: MatchMode.arsenal,
        seed: 42,
        lookAhead: false,
        automaticSpeedUp: false,
        skillLibrary: base.withDefinition(skill, PowerUpConfig.defaults),
      );
      final p = c.powerUps!..automaticSpawning = false;
      final owner = c.state.balls.first
        ..position = const Offset(-60, 0)
        ..velocity = Offset.zero;
      final target = c.state.balls.last
        ..position = const Offset(60, 0)
        ..velocity = Offset.zero;
      p.pickUp(
        owner,
        FieldPowerUp(
          kind: PowerUpKind.pistol,
          position: owner.position,
          spawnStep: 0,
        ),
      );
      owner
        ..aimTarget = target
        ..aimLeft = 1;
      for (var i = 0; i < 180 && p.hits == 0; i++) {
        c.tick(1 / 60);
      }
      expect(p.hits, greaterThan(0));
      expect(p.weaponImpacts.last.target, same(target));
      target.position = const Offset(50, 40);
      final hit = _Canvas();
      PowerUpPainter.paintImpacts(hit, c.state);
      expect(hit.translations.last, target.position);
      p.explosions.add(
        Explosion(
          position: Offset.zero,
          radius: 20,
          direction: const Offset(0, 1),
          kind: PowerUpKind.pistol,
          skillId: 'builtin.pistol',
        ),
      );
      final blast = _Canvas();
      PowerUpPainter.paint(blast, c.state, 180);
      expect(blast.rotations, contains(closeTo(math.pi / 2, 1e-9)));
    },
  );
  setUp(() async {
    await Future<void>.sync(() async {
      for (final entry in {
        'qa.hit': Colors.red,
        'qa.blast': Colors.blue,
        'qa.muzzle': Colors.yellow,
        'qa.trail': Colors.green,
      }.entries) {
        if (SpriteRegistry.has(entry.key)) continue;
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
    'muzzle appears on firing and a trail lives only with its projectile',
    () {
      var lib = library()
          .withEffect(
            const EffectDefinition(
              id: 'muzzle',
              name: 'Muzzle',
              spriteId: 'qa.muzzle',
              durationSeconds: 4 / 60,
              playback: EffectPlayback.natural,
            ),
          )
          .withEffect(
            const EffectDefinition(
              id: 'trail',
              name: 'Trail',
              spriteId: 'qa.trail',
              playback: EffectPlayback.loop,
            ),
          );
      final skill = lib.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults);
      lib = lib.withDefinition(
        skill.copyWith(
          visualBindings: {
            ...skill.visualBindings,
            SkillVisualRole.muzzle: const SkillVisualBinding(
              effectId: 'muzzle',
              attachment: EffectAttachment.hand,
            ),
            SkillVisualRole.trail: const SkillVisualBinding(
              effectId: 'trail',
              facing: EffectFacing.direction,
            ),
          },
        ),
        PowerUpConfig.defaults,
      );
      final c = MatchSimulationController(
        _balls,
        arenaRadius: 180,
        mode: MatchMode.arsenal,
        seed: 42,
        lookAhead: false,
        automaticSpeedUp: false,
        skillLibrary: lib,
      );
      final p = c.powerUps!..automaticSpawning = false;
      final owner = c.state.balls.first
        ..position = const Offset(-60, 0)
        ..velocity = Offset.zero;
      final target = c.state.balls.last
        ..position = const Offset(60, 0)
        ..velocity = Offset.zero;
      p.pickUp(
        owner,
        FieldPowerUp(
          kind: PowerUpKind.pistol,
          position: owner.position,
          spawnStep: 0,
        ),
      );
      expect(p.muzzleArtwork, isEmpty);
      owner
        ..aimTarget = target
        ..aimLeft = 1;
      c.tick(1 / 60);
      expect(p.muzzleArtwork, hasLength(1));
      expect(p.projectiles.single.visualAge, 0);
      final muzzle = _Canvas();
      PowerUpPainter.paintCasting(muzzle, c.state);
      expect(
        muzzle.draws.where(
          (d) => identical(d.$1, SpriteRegistry.frame('qa.muzzle')),
        ),
        hasLength(1),
      );
      final trail = _Canvas();
      PowerUpPainter.paint(trail, c.state, 180);
      expect(
        trail.draws.where(
          (d) => identical(d.$1, SpriteRegistry.frame('qa.trail')),
        ),
        hasLength(1),
      );
      for (var i = 0; i < 4; i++) {
        c.tick(1 / 60);
      }
      expect(p.muzzleArtwork, isEmpty);
      expect(p.projectiles, isNotEmpty);
      for (var i = 0; i < 180; i++) {
        c.tick(1 / 60);
      }
      expect(p.projectiles, isEmpty);
      final finished = _Canvas();
      PowerUpPainter.paint(finished, c.state, 180);
      expect(
        finished.draws.where(
          (d) => identical(d.$1, SpriteRegistry.frame('qa.trail')),
        ),
        isEmpty,
      );
    },
  );

  test('attachment, offsets, rotation and mirroring use ball-space units', () {
    const effect = ResolvedSkillEffect(
      spriteId: 'qa.hit',
      scale: 1,
      opacity: 1,
      tint: 0xffffffff,
      playback: EffectPlayback.once,
      offsetX: 1,
      offsetY: 2,
      rotationDegrees: 90,
      facing: EffectFacing.direction,
      attachment: EffectAttachment.hand,
    );
    final anchor = SkillEffectRenderer.attachment(
      effect,
      SkillVisualRole.casting,
      Offset.zero,
      owner: const Offset(20, 30),
      direction: const Offset(0, 1),
      radius: 10,
    );
    expect(anchor, const Offset(20, 41));
    final canvas = _Canvas();
    SkillEffectRenderer.paint(
      canvas,
      effect,
      anchor,
      8,
      0,
      12,
      direction: const Offset(0, 1),
      unitRadius: 10,
    );
    expect(canvas.translations.single, const Offset(0, 51));
    expect(canvas.rotations.single, closeTo(math.pi, 1e-9));
    const mirror = ResolvedSkillEffect(
      spriteId: 'qa.hit',
      scale: 1,
      opacity: 1,
      tint: 0xffffffff,
      playback: EffectPlayback.once,
      facing: EffectFacing.mirror,
      rotationDegrees: 30,
    );
    final mirrored = _Canvas();
    SkillEffectRenderer.paint(
      mirrored,
      mirror,
      Offset.zero,
      8,
      0,
      12,
      direction: const Offset(-1, 0),
    );
    expect(mirrored.scales.single, const Offset(-1, 1));
    expect(mirrored.rotations.single, closeTo(-math.pi / 6, 1e-9));
  });

  test(
    'casting uses local tint and opacity without applying the skill tint twice',
    () async {
      final base = library();
      final skill = base
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(
            spriteTint: 0xffff0000,
            visualBindings: const {
              SkillVisualRole.casting: SkillVisualBinding(
                effectId: 'hit',
                tint: 0xff00ff00,
                opacity: .5,
              ),
            },
          );
      final c = MatchSimulationController(
        _balls,
        arenaRadius: 180,
        mode: MatchMode.arsenal,
        seed: 42,
        lookAhead: false,
        skillLibrary: base.withDefinition(skill, PowerUpConfig.defaults),
      );
      c.powerUps!.automaticSpawning = false;
      final owner = c.state.balls.first
        ..position = const Offset(64, 64)
        ..velocity = Offset.zero;
      final target = c.state.balls.last
        ..position = const Offset(150, 64)
        ..velocity = Offset.zero;
      c.powerUps!.pickUp(
        owner,
        FieldPowerUp(
          kind: PowerUpKind.pistol,
          position: owner.position,
          spawnStep: 0,
        ),
      );
      owner
        ..aimLeft = 1
        ..aimTarget = target;
      c.tick(1 / 60);
      await Future<void>.sync(() async {
        final recorder = ui.PictureRecorder();
        PowerUpPainter.paintCasting(Canvas(recorder), c.state);
        final picture = recorder.endRecording();
        final image = await picture.toImage(128, 128);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final at = (64 * 128 + 64) * 4;
        expect(bytes!.getUint8(at), 0);
        expect(bytes.getUint8(at + 1), greaterThan(0));
        expect(bytes.getUint8(at + 2), 0);
        expect(bytes.getUint8(at + 3), closeTo(128, 1));
        image.dispose();
        picture.dispose();
      });
    },
  );

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
      await Future<void>.sync(() async {
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
          idPrefix: 'custom.qa-playback',
        );
        image.dispose();
        picture.dispose();
      });
      ResolvedSkillEffect effect(EffectPlayback playback) =>
          ResolvedSkillEffect(
            spriteId: 'custom.qa-playback.spin',
            scale: 1,
            opacity: 1,
            tint: 0xffffffff,
            playback: playback,
          );
      final first = SpriteRegistry.frame('custom.qa-playback.spin', 0);
      final last = SpriteRegistry.frame('custom.qa-playback.spin', 1);
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
