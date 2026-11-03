import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reverse in [false, true]) {
    test('pistol cannot pierce two targets in one tick reverse=$reverse', () {
      const owner = CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink);
      const a = CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime);
      const b = CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan);
      final match = MatchSimulationController(reverse ? [owner, b, a] : [owner, a, b],
          arenaRadius: 260, seed: 3030, mode: MatchMode.arsenal, lookAhead: false);
      match.powerUps!.automaticSpawning = false;
      final balls = {for (final ball in match.state.balls) ball.config.id: ball};
      balls['owner']!.position = const Offset(-220, 0);
      balls['a']!.position = const Offset(-90, 0);
      balls['b']!.position = const Offset(10, 0);
      for (final ball in match.state.balls) { ball.velocity = Offset.zero; }
      final firstLife = balls['a']!.life;
      final secondLife = balls['b']!.life;
      final shot = Projectile(owner: balls['owner']!, kind: PowerUpKind.pistol,
          position: const Offset(-180, 0), velocity: const Offset(18000, 0));
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(balls['a']!.life, lessThan(firstLife));
      expect(balls['b']!.life, secondLife);
      expect(shot.spent, isTrue);
    });
  }
}
