import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _players = [
  CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.orange),
  CustomBall(id: 'target', name: 'Target', primaryColor: Colors.blue, glowColor: Colors.cyan),
];

void main() {
  for (final inward in [true, false]) {
    test('circular center wall diagonal rim departure ${inward ? 'inward bounces' : 'outward escapes'}', () {
      final match = MatchSimulationController(_players,
        arenaRadius: 260, seed: 419, mode: MatchMode.arsenal,
        lookAhead: false, slowMotionLines: 0,
        centerObstacle: CenterObstacle.circle);
      match.powerUps!.automaticSpawning = false;
      final owner = match.state.balls.first;
      final target = match.state.balls.last;
      owner.position = const Offset(-220, -100);
      target.position = const Offset(220, 100);
      owner.velocity = Offset.zero;
      target.velocity = Offset.zero;
      final shot = Projectile(owner: owner, kind: PowerUpKind.pistol,
        position: Offset.zero, velocity: Offset.zero);
      final wall = match.arenaRadius * match.centerObstacleScale +
          match.powerUps!.projectileCollisionRadius(shot);
      shot.position = Offset(-wall, 0);
      shot.velocity = Offset(inward ? 900 : -900, 400);
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(shot.wallBounces, inward ? 1 : 0);
      expect(shot.position.dx.isFinite && shot.position.dy.isFinite, isTrue);
      expect(shot.velocity.dx.isFinite && shot.velocity.dy.isFinite, isTrue);
    });
  }
}
