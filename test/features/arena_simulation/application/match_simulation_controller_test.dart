import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

List<CustomBall> _twoBalls() => const [
      CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
      CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
    ];

void main() {
  test('initializes with balls placed inside the arena and even territory split', () {
    final controller = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 1);
    final state = controller.state;

    expect(state.balls.length, 2);
    for (final ball in state.balls) {
      expect(ball.position.distance, lessThanOrEqualTo(260.0));
    }
    expect(state.territory.countSectors('a'), 180);
    expect(state.territory.countSectors('b'), 180);
    expect(state.status, MatchStatus.running);
  });

  test('same seed and contestants produce identical state after N ticks (determinism)', () {
    final controllerA = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 99);
    final controllerB = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 99);

    for (var i = 0; i < 300; i++) {
      controllerA.tick(1 / 60);
      controllerB.tick(1 / 60);
    }

    final stateA = controllerA.state;
    final stateB = controllerB.state;

    expect(stateA.territory.sectorOwners, equals(stateB.territory.sectorOwners));
    for (var i = 0; i < stateA.balls.length; i++) {
      expect(stateA.balls[i].position, equals(stateB.balls[i].position));
      expect(stateA.balls[i].velocity, equals(stateB.balls[i].velocity));
    }
  });

  test('tick accumulates partial real time into fixed steps without drifting immediately', () {
    final controller = MatchSimulationController(_twoBalls(), arenaRadius: 260.0, seed: 5);
    final before = controller.state.balls.first.position;
    // Less than one fixed timestep (1/60 ~= 0.01667) should not advance physics yet.
    controller.tick(0.005);
    final after = controller.state.balls.first.position;
    expect(after, before);
  });
}
