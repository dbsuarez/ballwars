import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  const contestants = [
    CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.red),
    CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.blue),
  ];

  test('thread growth starts with one thread per ball', () {
    final simulation = MatchSimulationController(
      contestants, arenaRadius: 260, seed: 42,
      mode: MatchMode.threadGrowth, lookAhead: false,
    );
    expect(simulation.state.balls.map((b) => b.fanLines.length), [1, 1]);
  });

  test('existing Threads mode retains original starting allocation', () {
    final simulation = MatchSimulationController(
      contestants, arenaRadius: 260, seed: 42,
      mode: MatchMode.threads, lookAhead: false,
    );
    expect(simulation.state.balls.every((b) => b.fanLines.length > 1), isTrue);
  });

  test('thread growth earns exactly one thread on outer wall impact', () {
    final simulation = MatchSimulationController(
      contestants, arenaRadius: 260, seed: 42,
      mode: MatchMode.threadGrowth, lookAhead: false,
    );
    final ball = simulation.state.balls.first;
    ball.position = Offset(260 - ball.radius - 0.1, 0);
    ball.velocity = const Offset(400, 0);
    simulation.tick(MatchSimulationController.fixedTimestep);
    expect(ball.fanLines.length, 2);
  });
}
