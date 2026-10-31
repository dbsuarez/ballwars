import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall _ball(String id) => SimulationBall(
  config: CustomBall(
    id: id,
    name: id,
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
  position: Offset.zero,
  velocity: Offset.zero,
  radius: 20,
  lineCount: 0,
);

void main() {
  test('result lookup returns the matching live ball', () {
    final first = _ball('first');
    final second = _ball('second');
    expect(findResultBall([first, second], 'second'), same(second));
  });

  test('result lookup tolerates missing, null, and empty results', () {
    final balls = [_ball('first')];
    expect(findResultBall(balls, 'missing'), isNull);
    expect(findResultBall(balls, null), isNull);
    expect(findResultBall(const [], 'first'), isNull);
  });
}
