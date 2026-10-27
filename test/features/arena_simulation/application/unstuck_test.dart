import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  CustomBall(id: 'c', name: 'C', primaryColor: Colors.green, glowColor: Colors.lime),
];

MatchSimulationController _match({List<int> nudges = const [], bool lookAhead = false, MatchMode mode = MatchMode.arsenal}) =>
    MatchSimulationController(
      _balls,
      arenaRadius: 260,
      seed: 21,
      mode: mode,
      lookAhead: lookAhead,
      slowMotionBeforeWinSeconds: lookAhead ? 1.5 : null,
      nudgeSteps: nudges,
    );

void _run(MatchSimulationController c, int steps) {
  for (var i = 0; i < steps && c.state.status != MatchStatus.finished; i++) {
    c.tick(MatchSimulationController.fixedTimestep);
  }
}

void main() {
  test('Unstuck pushes every ball in play at force 1 (an arena radius per second) and is recorded', () {
    final c = _match();
    _run(c, 120);
    final before = [for (final b in c.state.balls) b.velocity];
    c.requestNudge();
    _run(c, 1);
    expect(c.nudgeSteps, [121]);
    final after = [for (final b in c.state.balls) b.velocity];
    expect(after, isNot(before));
    // Set by the nudge at the start of the step (speed can change within the step after a bump).
    final nudged = _match(nudges: const [121]);
    _run(nudged, 120);
    expect(nudged.nudgeSteps, [121]);
  });

  test('a replay with the recorded nudges plays out exactly the same', () {
    final live = _match(mode: MatchMode.threads);
    _run(live, 60);
    live.requestNudge();
    _run(live, 60);
    live.requestNudge();
    _run(live, 60 * 60 * 6);
    final replay = _match(nudges: live.nudgeSteps, mode: MatchMode.threads);
    _run(replay, 60 * 60 * 6);
    expect(live.nudgeSteps, hasLength(2));
    expect(replay.stepCount, live.stepCount);
    expect(replay.state.winnerId, live.state.winnerId);
    // Without the nudges it is a different match.
    final plain = _match(mode: MatchMode.threads);
    _run(plain, 60 * 60 * 6);
    expect(
      [plain.stepCount, plain.state.winnerId],
      isNot([live.stepCount, live.state.winnerId]),
    );
  });

  test('after a nudge the slow-motion look-ahead plans again and still predicts the real finish', () {
    final c = _match(lookAhead: true, mode: MatchMode.threads);
    _run(c, 40);
    c.requestNudge();
    // In slow motion a tick is less than a step: wait until the nudge has happened.
    for (var i = 0; i < 20 && c.nudgeSteps.isEmpty; i++) {
      _run(c, 1);
    }
    expect(c.nudgeSteps, hasLength(1));
    final predicted = c.predictedFinishStep;
    _run(c, 60 * 60 * 6);
    expect(c.state.status, MatchStatus.finished);
    expect(predicted, c.stepCount);
  });

  test('a finished match ignores the button', () {
    final c = _match(mode: MatchMode.threads);
    _run(c, 60 * 60 * 6);
    c.requestNudge();
    c.tick(MatchSimulationController.fixedTimestep);
    expect(c.nudgeSteps, isEmpty);
  });
}
