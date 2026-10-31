import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/arena_rotation.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

const _contestants = [
  CustomBall(id: 'red', name: 'Red', primaryColor: Colors.red,
      glowColor: Colors.orange),
  CustomBall(id: 'blue', name: 'Blue', primaryColor: Colors.blue,
      glowColor: Colors.cyan),
];

MatchSimulationController _match(MatchMode mode, {
  ArenaShape shape = ArenaShape.square,
  ArenaDecoration theme = ArenaDecoration.desert,
  bool rotateThemes = true,
  bool rotateShapes = true,
  CenterObstacle obstacle = CenterObstacle.none,
}) => MatchSimulationController(
  _contestants,
  arenaRadius: 260,
  seed: 12345,
  mode: mode,
  mayhem: true,
  endlessBattle: true,
  automaticSpeedUp: false,
  // Disable endgame slow motion so each tick advances exactly one step.
  slowMotionLines: 0,
  mayhemSeconds: 120,
  lookAhead: false,
  arenaShape: shape,
  arenaDecoration: theme,
  centerObstacle: obstacle,
  arenaRotation: ArenaRotation(
    rotateThemes: rotateThemes,
    rotateShapes: rotateShapes,
    intervalSeconds: 30,
  ),
);

void _advance(MatchSimulationController controller, int steps) {
  for (var i = 0; i < steps; i++) {
    controller.tick(MatchSimulationController.fixedTimestep);
  }
}

void main() {
  for (final mode in MatchMode.values) {
    test('$mode rotates theme and geometry at simulation step 1800', () {
      final match = _match(mode);
      _advance(match, 1799);
      expect(match.stepCount, 1799);
      expect(match.arenaShape, ArenaShape.square);
      expect(match.arenaDecoration, ArenaDecoration.desert);
      _advance(match, 1);
      expect(match.stepCount, 1800);
      expect(match.arenaShape, ArenaShape.circle);
      expect(match.arenaDecoration, ArenaDecoration.space);
      for (final ball in match.state.balls) {
        expect(ball.position.distance,
            lessThanOrEqualTo(match.arenaRadius - ball.radius + 0.001));
        for (final line in ball.fanLines) {
          expect(line.startPoint.distance,
              closeTo(match.arenaRadius, 0.01));
        }
      }
    });
  }

  test('transition reconciles live projectile and clears outgoing hazards', () {
    final match = _match(MatchMode.arsenal,
        obstacle: CenterObstacle.circle);
    _advance(match, 1799);
    final shot = Projectile(
      owner: match.state.balls.first,
      kind: PowerUpKind.pistol,
      position: const Offset(210, 210),
      velocity: const Offset(15, 15),
    );
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.arenaThemeHazards.add(ArenaThemeHazard(
      kind: ArenaThemeHazardKind.quicksand,
      position: const Offset(10, 10),
      spawnStep: match.stepCount,
    ));
    _advance(match, 1);
    expect(match.arenaShape, ArenaShape.circle);
    expect(shot.position.distance, lessThanOrEqualTo(match.arenaRadius - 2 + 0.01));
    expect(shot.velocity.dx + shot.velocity.dy, lessThan(0));
    expect(match.powerUps!.arenaThemeHazards, isEmpty);
  });

  test('independent rotations leave the disabled dimension unchanged', () {
    final match = _match(MatchMode.arsenal,
        rotateThemes: false, rotateShapes: true,
        obstacle: CenterObstacle.square);
    _advance(match, 1800);
    expect(match.stepCount, 1800);
    expect(match.arenaShape, ArenaShape.circle);
    expect(match.arenaDecoration, ArenaDecoration.desert);
  });

  test('circle to square and back keeps all live balls inside the boundary', () {
    final match = _match(MatchMode.threads,
        shape: ArenaShape.circle,
        theme: ArenaDecoration.neonGrid,
        obstacle: CenterObstacle.square);
    _advance(match, 1800);
    expect(match.stepCount, 1800);
    expect(match.arenaShape, ArenaShape.square);
    for (final ball in match.state.balls) {
      final limit = match.arenaRadius - ball.radius;
      expect(ball.position.dx.abs(), lessThanOrEqualTo(limit + 0.01));
      expect(ball.position.dy.abs(), lessThanOrEqualTo(limit + 0.01));
    }
    _advance(match, 1800);
    expect(match.stepCount, 3600);
    expect(match.arenaShape, ArenaShape.circle);
    for (final ball in match.state.balls) {
      expect(ball.position.distance,
          lessThanOrEqualTo(match.arenaRadius - ball.radius + 0.01));
      for (final line in ball.fanLines) {
        expect(line.startPoint.distance,
            closeTo(match.arenaRadius, 0.01));
      }
    }
  });

  test('live arena changes are reproducible with the same simulation seed', () {
    final first = _match(MatchMode.arsenal,
        obstacle: CenterObstacle.circle);
    final second = _match(MatchMode.arsenal,
        obstacle: CenterObstacle.circle);
    _advance(first, 1800);
    _advance(second, 1800);
    expect(first.stepCount, second.stepCount);
    expect(first.arenaShape, second.arenaShape);
    expect(first.arenaDecoration, second.arenaDecoration);
    expect(first.state.balls.length, second.state.balls.length);
    for (var i = 0; i < first.state.balls.length; i++) {
      expect(first.state.balls[i].position,
          second.state.balls[i].position);
      expect(first.state.balls[i].velocity,
          second.state.balls[i].velocity);
    }
  });

}
