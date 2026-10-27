import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _arenaRadius = 260.0;

const _balls = [
  CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
  CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
  CustomBall(id: 'c', name: 'C', primaryColor: Colors.green, glowColor: Colors.lightGreen),
];

MatchSimulationController _endless({int seed = 5, int? endStep, bool endless = true}) =>
    MatchSimulationController(
      _balls,
      arenaRadius: _arenaRadius,
      seed: seed,
      mode: MatchMode.arsenal,
      endlessBattle: endless,
      lookAhead: false,
      endAfterKnockoutStep: endStep,
    );

void main() {
  test('ending an endless battle waits for the next knockout', () {
    final match = _endless();
    final reference = _endless();
    // Play a little first, so the tally has something in it.
    for (var i = 0; i < 600; i++) {
      match.tick(1 / 60);
      reference.tick(1 / 60);
    }
    match.requestEndAfterKnockout();
    expect(match.endRequested, isTrue);

    // The reference keeps playing; our match must end exactly at its next knockout.
    var guard = 0;
    while (match.state.status != MatchStatus.finished && guard++ < 60 * 60 * 10) {
      final knockoutsBefore = reference.knockouts;
      match.tick(1 / 60);
      reference.tick(1 / 60);
      if (match.state.status != MatchStatus.finished) {
        expect(reference.knockouts, knockoutsBefore, reason: 'no knockout yet, so still running');
      } else {
        expect(reference.knockouts, greaterThan(knockoutsBefore));
      }
    }
    expect(match.state.status, MatchStatus.finished);
    expect(match.endStep, 601);

    final defeated = match.state.balls.firstWhere((b) => b.config.id == match.lastEliminatedId);
    expect(defeated.isEliminated, isTrue, reason: 'the defeated ball does not respawn');

    // The winner is the tally leader among the balls still standing.
    final ranked = match.state.balls.where((b) => !b.isEliminated).toList()
      ..sort((x, y) {
        final ko = (match.eliminations[y.config.id] ?? 0).compareTo(match.eliminations[x.config.id] ?? 0);
        if (ko != 0) return ko;
        final d = (match.deaths[x.config.id] ?? 0).compareTo(match.deaths[y.config.id] ?? 0);
        if (d != 0) return d;
        final life = y.life.compareTo(x.life);
        if (life != 0) return life;
        return match.state.balls.indexOf(x).compareTo(match.state.balls.indexOf(y));
      });
    expect(match.state.winnerId, ranked.first.config.id);
    expect(match.winningMove, isNotNull);
    expect(match.winningMove, isNot('Knockout lead'));
  });

  test('the defeated ball never wins, even when it leads the tally; the move is its last one', () {
    final match = _endless(seed: 2);
    match.requestEndAfterKnockout();
    match.tick(1 / 60);
    expect(match.endStep, 1);
    expect(match.state.status, isNot(MatchStatus.finished));
    final a = match.state.balls.firstWhere((b) => b.config.id == 'a');
    final b = match.state.balls.firstWhere((b) => b.config.id == 'b');
    match.eliminations['b'] = 5;
    match.damage(b, 1000, attacker: a, move: 'Test blade');
    match.tick(1 / 60);

    expect(match.state.status, MatchStatus.finished);
    expect(match.lastEliminatedId, 'b');
    expect(b.isEliminated, isTrue);
    expect(match.eliminations['b'], 5, reason: 'b still leads the tally');
    expect(match.eliminations['a'], 1);
    expect(match.state.winnerId, 'a');
    expect(match.winningMove, 'Test blade');
  });

  test('replaying with endAfterKnockoutStep reproduces the winner', () {
    final live = _endless(seed: 11);
    for (var i = 0; i < 300; i++) {
      live.tick(1 / 60);
    }
    live.requestEndAfterKnockout();
    var guard = 0;
    while (live.state.status != MatchStatus.finished && guard++ < 60 * 60 * 10) {
      live.tick(1 / 60);
    }
    expect(live.state.status, MatchStatus.finished);

    final replay = _endless(seed: 11, endStep: live.endStep);
    guard = 0;
    while (replay.state.status != MatchStatus.finished && guard++ < 60 * 60 * 10) {
      replay.tick(1 / 60);
    }
    expect(replay.stepCount, live.stepCount);
    expect(replay.state.winnerId, live.state.winnerId);
    expect(replay.lastEliminatedId, live.lastEliminatedId);
    expect(replay.winningMove, live.winningMove);
    expect(replay.eliminations, live.eliminations);
    expect(replay.deaths, live.deaths);
    expect(replay.endStep, live.endStep);
  });

  test('the request is ignored outside endless battles and after finish', () {
    final normal = _endless(endless: false);
    normal.requestEndAfterKnockout();
    expect(normal.endRequested, isFalse);
    normal.tick(1 / 60);
    expect(normal.endStep, isNull);

    final mayhem = MatchSimulationController(
      _balls,
      arenaRadius: _arenaRadius,
      seed: 3,
      mode: MatchMode.arsenal,
      endlessBattle: true,
      mayhem: true,
      lookAhead: false,
    );
    mayhem.requestEndAfterKnockout();
    expect(mayhem.endRequested, isFalse);

    final finished = _endless(seed: 11);
    finished.requestEndAfterKnockout();
    var guard = 0;
    while (finished.state.status != MatchStatus.finished && guard++ < 60 * 60 * 10) {
      finished.tick(1 / 60);
    }
    final step = finished.endStep;
    finished.requestEndAfterKnockout();
    finished.tick(1 / 60);
    expect(finished.endStep, step);
  });
}
