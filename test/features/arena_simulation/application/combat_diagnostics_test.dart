import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  test('combat diagnostics expose per-match counters without mutable access', () {
    final match = MatchSimulationController(
      const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red,
            glowColor: Colors.orange),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue,
            glowColor: Colors.cyan),
      ],
      arenaRadius: 260,
      mode: MatchMode.arsenal,
      lookAhead: false,
      seed: 42,
    );
    final stats = match.powerUps!.targetingDiagnostics;
    expect(stats['targetSwitches'], 0);
    expect(stats['homingRetargets'], 0);
    expect(stats['projectileSweeps'], 0);
    expect(stats['projectileContacts'], 0);
    expect(stats['projectileCenterWallBounces'], 0);
    expect(() => stats['targetSwitches'] = 99, throwsUnsupportedError);
  });
}
