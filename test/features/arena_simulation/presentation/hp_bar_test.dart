import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/hp_bar.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];

MatchSimulationController _match(MatchMode mode) => MatchSimulationController(
  _balls,
  arenaRadius: 260,
  seed: 3,
  mode: mode,
  lookAhead: false,
);

/// Puts the two balls at known spots so a pixel above each can be sampled.
void _place(MatchSimulationController match) {
  final a = match.state.balls[0];
  final b = match.state.balls[1];
  a
    ..position = const Offset(-100, 40)
    ..radius = 30;
  b
    ..position = const Offset(100, 40)
    ..radius = 30;
}

/// The arena background at the spot [_pixelAbove] samples for [ball]: the same frame with every fan
/// line gone and [ball] moved away, so nothing but the arena is drawn there.
Future<Color> _backgroundAbove(
  MatchSimulationController match,
  SimulationBall ball,
) async {
  final spot = ball.position;
  final radius = ball.radius;
  final eliminated = ball.isEliminated;
  for (final b in match.state.balls) {
    b.fanLines.clear();
  }
  ball
    ..position = const Offset(0, 180)
    ..isEliminated = false;
  final color = await _pixelAt(match, spot, radius, showHpBars: true);
  ball
    ..position = spot
    ..isEliminated = eliminated;
  return color;
}

Future<Color> _pixelAbove(
  MatchSimulationController match,
  SimulationBall ball, {
  required bool showHpBars,
  double dx = 0,
}) =>
    _pixelAt(match, ball.position, ball.radius, showHpBars: showHpBars, dx: dx);

/// The pixel where the HP bar of a ball of [radius] at [spot] sits (moved by [dx]).
Future<Color> _pixelAt(
  MatchSimulationController match,
  Offset spot,
  double radius, {
  required bool showHpBars,
  double dx = 0,
}) async {
  final recorder = ui.PictureRecorder();
  // rimInset 0 with a 520 canvas and arena radius 260: world (x, y) is pixel (260 + x, 260 + y).
  ArenaPainter(
    state: match.state,
    arenaRadius: 260,
    rimInset: 0,
    rimAngle: 0,
    showEffects: false,
    showHpBars: showHpBars,
  ).paint(Canvas(recorder), const Size(520, 520));
  final image = await recorder.endRecording().toImage(520, 520);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final x = (260 + spot.dx + dx).floor();
  final y = (260 + spot.dy - radius * 1.35).floor();
  final i = (y * 520 + x) * 4;
  image.dispose();
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

void main() {
  group('hpBarFor', () {
    test('sits centered above the ball with the given size', () {
      final match = _match(MatchMode.threads);
      _place(match);
      final ball = match.state.balls.first;
      final bar = hpBarFor(ball, maxLife: PowerUpTuning.arenaMaxLife)!;
      expect(bar.track.center.dx, closeTo(-100, 1e-9));
      expect(bar.track.center.dy, closeTo(40 - 30 * 1.35, 1e-9));
      expect(bar.track.width, closeTo(30 * 1.6, 1e-9));
      expect(bar.track.height, closeTo(30 * 0.16, 1e-9));
      ball.radius = 10;
      expect(hpBarFor(ball, maxLife: 150)!.track.height, 3);
    });

    test('line modes fill by lines left of the starting lines', () {
      final match = _match(MatchMode.threads);
      final ball = match.state.balls.first;
      expect(ball.startLines, greaterThan(0));
      ball.lineCount = ball.startLines;
      var bar = hpBarFor(ball, maxLife: 150)!;
      expect(bar.ratio, 1);
      expect(bar.color, HpBar.green);
      expect(bar.level, HpLevel.high);
      expect(bar.overflow, 0);
      ball.lineCount = (ball.startLines * 0.4).round();
      bar = hpBarFor(ball, maxLife: 150)!;
      expect(bar.ratio, closeTo(ball.lineCount / ball.startLines, 1e-9));
      expect(bar.color, HpBar.amber);
      expect(bar.level, HpLevel.medium);
      expect(bar.fill.width, closeTo(bar.track.width * bar.ratio, 1e-9));
      expect(bar.fill.left, bar.track.left);
      ball.lineCount = (ball.startLines * 0.2).round();
      expect(hpBarFor(ball, maxLife: 150)!.color, HpBar.red);
      expect(hpBarFor(ball, maxLife: 150)!.level, HpLevel.low);
    });

    test('Arsenal fills by life, with a gold segment past full life', () {
      final match = _match(MatchMode.arsenal);
      final ball = match.state.balls.first;
      expect(ball.startLines, 0);
      ball.life = 60;
      var bar = hpBarFor(ball, maxLife: 150)!;
      expect(bar.ratio, closeTo(0.6, 1e-9));
      expect(bar.color, HpBar.green);
      expect(bar.overflow, 0);
      ball.life = 50;
      expect(hpBarFor(ball, maxLife: 150)!.color, HpBar.amber);
      ball.life = 25;
      expect(hpBarFor(ball, maxLife: 150)!.color, HpBar.red);
      ball.life = -5;
      expect(hpBarFor(ball, maxLife: 150)!.ratio, 0);
      ball.life = 125;
      bar = hpBarFor(ball, maxLife: 150)!;
      expect(bar.ratio, 1);
      expect(bar.overflow, closeTo(0.5, 1e-9));
      expect(bar.goldRect.width, closeTo(bar.track.width * 0.5, 1e-9));
      ball.life = 400;
      expect(hpBarFor(ball, maxLife: 150)!.overflow, 1);
    });

    test('no bar for an eliminated ball', () {
      final match = _match(MatchMode.threads);
      final ball = match.state.balls.first..isEliminated = true;
      expect(hpBarFor(ball, maxLife: 150), isNull);
    });
  });

  test('each level has its own color', () {
    expect(HpLevel.high.color, HpBar.green);
    expect(HpLevel.medium.color, HpBar.amber);
    expect(HpLevel.low.color, HpBar.red);
  });

  group('ArenaPainter HP bars', () {
    test('draws a green bar above each healthy ball when on', () async {
      final match = _match(MatchMode.threads);
      _place(match);
      for (final ball in match.state.balls) {
        expect(await _pixelAbove(match, ball, showHpBars: true), HpBar.green);
      }
    });

    test('draws nothing when off', () async {
      final match = _match(MatchMode.threads);
      _place(match);
      final ball = match.state.balls.first;
      final background = await _backgroundAbove(match, ball);
      expect(background, isNot(HpBar.green));
      expect(await _pixelAbove(match, ball, showHpBars: false), background);
    });

    test('the empty part shows the track, red when low', () async {
      final match = _match(MatchMode.arsenal);
      _place(match);
      final ball = match.state.balls.first..life = 20;
      // The left edge is filled red, the middle is the dark track.
      expect(
        await _pixelAbove(match, ball, showHpBars: true, dx: -20),
        HpBar.red,
      );
      expect(
        await _pixelAbove(match, ball, showHpBars: true),
        isNot(HpBar.red),
      );
    });

    test('draws nothing for an eliminated ball', () async {
      final match = _match(MatchMode.threads);
      _place(match);
      final ball = match.state.balls.first..isEliminated = true;
      final background = await _backgroundAbove(match, ball);
      expect(background, isNot(HpBar.green));
      expect(await _pixelAbove(match, ball, showHpBars: true), background);
    });
  });
}
