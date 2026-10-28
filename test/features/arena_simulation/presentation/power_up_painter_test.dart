import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_pixel_art.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'paints field power-ups, projectiles, mines, blasts and ball effects without throwing',
    () {
      final c = MatchSimulationController(
        _balls,
        arenaRadius: 260,
        seed: 1,
        mode: MatchMode.arsenal,
        lookAhead: false,
      );
      final p = c.powerUps!;
      final a = c.state.balls[0];
      final b = c.state.balls[1];
      for (final kind in PowerUpKind.values) {
        p.field.add(
          FieldPowerUp(
            kind: kind,
            position: Offset(kind.index * 15.0 - 80, 60),
            spawnStep: 0,
          ),
        );
      }
      p.projectiles.add(
        Projectile(
          owner: a,
          kind: PowerUpKind.pistol,
          position: Offset.zero,
          velocity: const Offset(100, 0),
        ),
      );
      p.mines.add(
        ArmedMine(owner: a, position: const Offset(0, -50), armedStep: 0),
      );
      p.portals.add(ArenaPortal(position: const Offset(180, 0), spawnStep: 0));
      p.spikeWalls.add(
        SpikeWall(position: const Offset(0, 180), angle: 1, spawnStep: 0),
      );
      p.stickyGoo.add(const StickyGoo(position: Offset(-180, 0), spawnStep: 0));
      p.slashMarks.add(SlashMark(position: const Offset(20, 20), angle: 1));
      p.explosions.add(Explosion(position: const Offset(30, 30), radius: 70));
      for (final kind in ArenaThemeHazardKind.values) {
        p.arenaThemeHazards.add(
          ArenaThemeHazard(
            kind: kind,
            position: Offset(kind.index * 35.0 - 50, 0),
            spawnStep: 0,
            angle: 0.7,
          ),
        );
      }
      a
        ..held = PowerUpKind.shield
        ..aimTarget = b
        ..aimLeft = 10
        ..frozenLeft = 5;
      b
        ..held = PowerUpKind.pistol
        ..ghostLeft = 5;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      PowerUpPainter.paint(canvas, c.state, 260);
      for (final decoration in ArenaDecoration.values) {
        ArenaPainter(
          state: c.state,
          arenaRadius: 260,
          rimAngle: 0,
          arenaDecoration: decoration,
        ).paint(canvas, const Size(600, 600));
      }
      expect(recorder.endRecording(), isNotNull);
    },
  );

  test('shadow clones draw the owner body once per clone in every look', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: 260,
      seed: 1,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );
    final [owner, target] = c.state.balls;
    final attack = ShadowCloneAttack(owner: owner, target: target, clones: 3);
    c.powerUps!.shadowCloneAttacks.add(attack);
    for (final age in [0, 6, 20, 30, 60, 70]) {
      attack.age = age;
      if (age >= 60) attack.vanishAt = 58;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final drawn = <SimulationBall>[];
      PowerUpPainter.paintShadowClones(
        canvas,
        c.state,
        paintBody: (_, ball) => drawn.add(ball),
      );
      expect(drawn, age == 0 || age == 70 ? isEmpty : hasLength(3));
      expect(drawn.every((ball) => identical(ball, owner)), isTrue);
      for (final look in BallLook.values) {
        ArenaPainter(
          state: c.state,
          arenaRadius: 260,
          rimAngle: 0,
          look: look,
        ).paint(canvas, const Size(600, 600));
      }
      expect(recorder.endRecording(), isNotNull);
    }
  });

  test('every power-up has its own glyph color', () {
    final colors = {
      for (final kind in PowerUpKind.values) PowerUpPainter.colorOf(kind),
    };
    expect(colors.length, PowerUpKind.values.length);
  });

  test('portal oval rotation conforms to every arena edge', () {
    expect(PowerUpPainter.portalRotationFor(const Offset(100, 0)), 0);
    expect(
      PowerUpPainter.portalRotationFor(const Offset(0, 100)),
      closeTo(math.pi / 2, 1e-9),
    );
    expect(
      PowerUpPainter.portalRotationFor(const Offset(-100, 0)).abs(),
      closeTo(math.pi, 1e-9),
    );
    expect(
      PowerUpPainter.portalRotationFor(const Offset(0, -100)),
      closeTo(-math.pi / 2, 1e-9),
    );
  });

  test('spike rail is anchored exactly to the arena edge', () {
    const arenaRadius = 260.0;
    const spikeRadius = 18.0;
    final base = PowerUpPainter.spikeBaseRadius(arenaRadius, spikeRadius);
    expect(base + spikeRadius * 0.4, arenaRadius);
  });

  test('orbiting flail moves around the ball as simulation steps advance', () {
    const center = Offset(12, -8);
    const radius = 20.0;
    final start = PowerUpPainter.orbitingFlailCenter(center, radius, 0);
    final later = PowerUpPainter.orbitingFlailCenter(center, radius, 15);
    expect(start, isNot(later));
    expect((start - center).distance, closeTo(radius * 2.25, 1e-9));
    expect((later - center).distance, closeTo(radius * 2.25, 1e-9));
  });

  test('tornado victim overlay is centered over the ball', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: 260,
      seed: 2,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );
    final ball = c.state.balls.first..position = const Offset(40, 70);
    final center = PowerUpPainter.tornadoVisualCenter(ball);
    expect(center, ball.position);
  });

  test('hilted blades are held slightly inside their artwork', () {
    final c = MatchSimulationController(
      _balls,
      arenaRadius: 260,
      seed: 3,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );
    final ball = c.state.balls.first
      ..position = Offset.zero
      ..velocity = const Offset(100, 0);

    for (final blade in const [PowerUpKind.knife, PowerUpKind.sword]) {
      final center = PowerUpPainter.heldCenter(ball, weapon: blade);
      expect(center.dx, closeTo(ball.radius * 1.8, 1e-9), reason: blade.label);
      expect(center.dy, closeTo(0, 1e-9), reason: blade.label);
    }
  });

  test('every selection icon paints visible pixels', () async {
    for (final kind in PowerUpKind.values) {
      final recorder = ui.PictureRecorder();
      PowerUpSprites.paintIcon(
        Canvas(recorder),
        kind,
        const Rect.fromLTWH(0, 0, 32, 32),
      );
      final image = await recorder.endRecording().toImage(32, 32);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(
        bytes!.buffer.asUint8List().indexed.any(
          (pixel) => pixel.$1 % 4 == 3 && pixel.$2 > 0,
        ),
        isTrue,
        reason: '${kind.label} painted a transparent icon',
      );
      image.dispose();
    }
  });

  test('the master sheet supplies one isolated image for every item', () async {
    await PowerUpSprites.load();
    for (final kind in PowerUpKind.values) {
      final image = PowerUpSprites.of(kind);
      expect(image, isNotNull, reason: '${kind.label} has no sheet crop');
      expect(image!.width, 64, reason: kind.label);
      expect(image.height, 64, reason: kind.label);
    }
    for (final kind in EffectSprite.values) {
      final image = SpriteRegistry.frame(PowerUpSprites.effectId(kind));
      expect(image, isNotNull, reason: '$kind has no effect crop');
      expect(image!.width, 96, reason: '$kind');
      expect(image.height, 96, reason: '$kind');
    }
    for (final kind in ProjectileSprite.values) {
      final image = SpriteRegistry.frame(PowerUpSprites.projectileId(kind));
      expect(image, isNotNull, reason: '$kind has no projectile crop');
      expect(image!.width, 96, reason: '$kind');
      expect(image.height, 96, reason: '$kind');
    }
    for (final kind in AnimatedEffect.values) {
      // Lightning uses the supplied eight-frame, higher-resolution artwork.
      final frameCount = kind == AnimatedEffect.lightning ? 8 : 4;
      final frameSize = kind == AnimatedEffect.lightning ? 192 : 96;
      for (var frame = 0; frame < frameCount; frame++) {
        final image = SpriteRegistry.frame(PowerUpSprites.animId(kind), frame);
        expect(image, isNotNull, reason: '$kind frame $frame is missing');
        expect(image!.width, frameSize, reason: '$kind frame $frame');
        expect(image.height, frameSize, reason: '$kind frame $frame');
      }
    }
  });

  test('every item has a complete hand-authored 16 by 16 sprite', () {
    const generatedPhase8 = {
      PowerUpKind.friedChicken,
      PowerUpKind.sniperRifle,
      PowerUpKind.busterSword,
      PowerUpKind.ragingDemon,
    };
    expect(
      pixelIcons.keys.toSet(),
      PowerUpKind.values.toSet().difference(generatedPhase8),
    );
    for (final kind in pixelIcons.keys) {
      final rows = pixelIcons[kind]!;
      expect(rows, hasLength(pixelSize), reason: kind.label);
      for (final row in rows) {
        expect(row.length, pixelSize, reason: '${kind.label}: $row');
        expect(
          row.runes.every(
            (pixel) =>
                pixelPalette.containsKey(String.fromCharCode(pixel)) ||
                pixel == 46,
          ),
          isTrue,
          reason: '${kind.label}: $row',
        );
      }
    }
  });
}
