
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchSimulationController arena() {
    final match = MatchSimulationController(
      const [
        CustomBall(id: 'a', name: 'Shooter', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'Mirror', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
      arenaRadius: 260,
      seed: 42,
      mode: MatchMode.arsenal,
      lookAhead: false,
    );
    match.powerUps!.automaticSpawning = false;
    return match;
  }

  for (final direction in [1.0, -1.0]) {
    test('exact-center mirror contact separates against incoming direction $direction', () {
      final match = arena();
      final shooter = match.state.balls.first;
      final mirror = match.state.balls.last;
      shooter.position = Offset(-150 * direction, 0);
      mirror.position = Offset.zero;
      mirror.mirrorCharges = 1;
      final shot = Projectile(
        owner: shooter,
        kind: PowerUpKind.pistol,
        position: mirror.position,
        velocity: Offset(100 * direction, 0),
      );
      match.powerUps!.projectiles.add(shot);
      match.powerUps!.step();
      expect(shot.spent, isFalse);
      expect(shot.owner, same(mirror));
      expect(shot.velocity.dx * direction, lessThan(0));
      expect(shot.position.dx * direction, lessThan(0));
      expect(shot.position.dx.isFinite, isTrue);
      expect(shot.position.dy.isFinite, isTrue);
      expect(mirror.mirrorCharges, 0);
    });
  }
}
