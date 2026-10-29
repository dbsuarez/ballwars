import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:ballwars/core/sprites/sprite_registry.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

Future<Map<String, Object>> runSixBallProfile() async {
  await PowerUpSprites.load();
  final match = MatchSimulationController(
    [
      for (var i = 0; i < 6; i++)
        CustomBall(
          id: 'profile-$i',
          name: 'Ball $i',
          primaryColor: Colors.primaries[i],
          glowColor: Colors.primaries[i],
        ),
    ],
    arenaRadius: 180,
    seed: 142,
    mode: MatchMode.arsenal,
    mayhem: true,
    mayhemSeconds: 120,
    endlessBattle: true,
    automaticSpeedUp: false,
    lookAhead: false,
  );
  final p = match.powerUps!;
  p.automaticSpawning = false;
  final cpu = <int>[], raster = <int>[];
  var peakProjectiles = 0, peakSources = 0, peakParticles = 0;
  final watch = Stopwatch();
  const pool = [
    PowerUpKind.pistol,
    PowerUpKind.shotgun,
    PowerUpKind.molotov,
    PowerUpKind.rocketLauncher,
    PowerUpKind.fireWall,
    PowerUpKind.boomerang,
  ];
  for (var step = 0; step < 720; step++) {
    if (step % 180 == 0) {
      for (var i = 0; i < 6; i++) {
        final b = match.state.balls[i];
        p.pickUp(
          b,
          FieldPowerUp(
            kind: pool[(step ~/ 180 + i) % pool.length],
            position: b.position,
            spawnStep: step,
          ),
        );
      }
    }
    watch
      ..reset()
      ..start();
    match.tick(1 / 60);
    watch.stop();
    cpu.add(watch.elapsedMicroseconds);
    peakProjectiles = peakProjectiles > p.projectiles.length
        ? peakProjectiles
        : p.projectiles.length;
    peakSources = peakSources > p.persistentEffects.handles.length
        ? peakSources
        : p.persistentEffects.handles.length;
    peakParticles = peakParticles > match.state.particles.particles.length
        ? peakParticles
        : match.state.particles.particles.length;
    if (step % 6 == 0) {
      watch
        ..reset()
        ..start();
      final recorder = ui.PictureRecorder();
      ArenaPainter(
        state: match.state,
        arenaRadius: 180,
        rimAngle: 0,
        background: Colors.black,
        rimColor: Colors.white,
        look: BallLook.faces,
      ).paint(Canvas(recorder), const Size(360, 360));
      final picture = recorder.endRecording(),
          image = await picture.toImage(360, 360);
      image.dispose();
      picture.dispose();
      watch.stop();
      raster.add(watch.elapsedMicroseconds);
    }
  }
  Map<String, num> stats(List<int> samples) {
    final sorted = [...samples]..sort();
    return {
      'mean_us': samples.reduce((a, b) => a + b) / samples.length,
      'p95_us': sorted[(sorted.length * .95).floor()],
    };
  }

  // Output is intentionally observational, with no flaky wall-time threshold.
  return {
    'balls': 6,
    'simulation_steps': 720,
    'raster_frames': raster.length,
    'cpu': stats(cpu),
    'raster': stats(raster),
    'decoded_bytes': SpriteRegistry.decodedBytes,
    'peak_projectiles': peakProjectiles,
    'peak_sources': peakSources,
    'peak_particles': peakParticles,
  };
}
