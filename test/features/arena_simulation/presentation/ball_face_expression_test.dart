import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball(String id, Offset at) => SimulationBall(
      config: CustomBall(id: id, name: id, primaryColor: Colors.red, glowColor: Colors.pink),
      position: at,
      velocity: Offset.zero,
      radius: 30,
      lineCount: 0,
    );

void main() {
  test('expression follows health and hits', () {
    final b = _ball('a', Offset.zero);
    expect(expressionFor(b, 0.9), FaceExpression.happy);
    expect(expressionFor(b, 0.61), FaceExpression.happy);
    expect(expressionFor(b, 0.6), FaceExpression.worried);
    expect(expressionFor(b, 0.3), FaceExpression.worried);
    expect(expressionFor(b, 0.29), FaceExpression.hurt);
    b.frozenLeft = 10;
    expect(expressionFor(b, 0.9), FaceExpression.shocked);
    b.hurtFlashLeft = 5;
    expect(expressionFor(b, 0.9), FaceExpression.wince, reason: 'a fresh hit wins over everything');
  });

  test('pupils look toward the nearest opponent', () {
    final me = _ball('a', Offset.zero);
    final near = _ball('b', const Offset(100, 0));
    final far = _ball('c', const Offset(0, -300));
    final look = pupilOffset(me, [me, near, far], 10);
    expect(look.dx, closeTo(3.5, 1e-9));
    expect(look.dy, closeTo(0, 1e-9));

    near.isEliminated = true;
    final up = pupilOffset(me, [me, near, far], 10);
    expect(up.dy, closeTo(-3.5, 1e-9));

    far.isEliminated = true;
    expect(pupilOffset(me, [me, near, far], 10), Offset.zero);
  });

  test('every expression paints', () {
    final me = _ball('a', Offset.zero);
    final other = _ball('b', const Offset(80, 20));
    for (final health in [0.9, 0.5, 0.1]) {
      final recorder = ui.PictureRecorder();
      paintSmiley(Canvas(recorder), me, health, [me, other]);
      expect(recorder.endRecording(), isNotNull);
    }
  });
}
