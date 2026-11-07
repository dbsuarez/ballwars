import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';

final _balls = List.generate(
  6,
  (i) => CustomBall(
    id: 'stop-$i',
    name: 'Ball $i',
    primaryColor: const Color(0xff4488ff),
    glowColor: const Color(0xffffffff),
  ),
);

MatchSimulationController _match(int revision) => MatchSimulationController(
  _balls,
  arenaRadius: 260,
  seed: 31,
  lookAhead: false,
  simulationRevision: revision,
  mode: MatchMode.arsenal,
  mayhem: true,
  endlessBattle: true,
  powerUpKinds: const {},
);

void main() {
  test(
    'six-step death stop freezes survivors while ghost rises, then resumes',
    () {
      final match = _match(11);
      match.state.balls.first.life = 0;
      match.tick(1 / 60);
      final survivor = match.state.balls.last;
      final position = survivor.position;
      final velocity = survivor.velocity;
      for (var i = 0; i < MatchSimulationController.deathHitStopSteps; i++) {
        match.tick(1 / 60);
        expect(survivor.position, position);
        expect(survivor.velocity, velocity);
      }
      expect(match.state.deathGhosts.single.age, closeTo(.1, 1e-8));
      match.tick(1 / 60);
      expect(survivor.position, isNot(position));
      for (var i = 0; i < 40; i++) {
        match.tick(1 / 60);
      }
      expect(match.state.balls.first.isEliminated, isFalse);
      expect(match.state.deathGhosts, isEmpty);
    },
  );
  test('simultaneous deaths share one short stop', () {
    final match = _match(11);
    for (final ball in match.state.balls.take(3)) {
      ball.life = 0;
    }
    match.tick(1 / 60);
    expect(match.state.deathGhosts, hasLength(3));
    final survivor = match.state.balls.last;
    final position = survivor.position;
    for (var i = 0; i < 6; i++) {
      match.tick(1 / 60);
    }
    expect(survivor.position, position);
    match.tick(1 / 60);
    expect(survivor.position, isNot(position));
  });
  test('revision 10 replays retain uninterrupted survivor movement', () {
    final match = _match(10);
    match.state.balls.first.life = 0;
    match.tick(1 / 60);
    final survivor = match.state.balls.last;
    final position = survivor.position;
    match.tick(1 / 60);
    expect(survivor.position, isNot(position));
  });
  test('revision 11 replays round-trip with the death stop rule', () {
    final link = ReplayLink(
      contestants: _balls,
      seed: 31,
      speedMultiplier: 1,
      simulationRevision: 11,
      mode: MatchMode.arsenal,
      mayhem: true,
      endlessBattle: true,
    );
    final parsed = ReplayLink.fromUri(
      link.toUri(presetIds: const {}),
      presets: const [],
    );
    expect(parsed, isNotNull);
    expect(parsed!.simulationRevision, 11);
  });
}
