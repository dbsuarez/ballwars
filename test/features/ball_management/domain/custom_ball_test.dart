import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('constructs with defaults', () {
    const ball = CustomBall(
      id: 'a',
      name: 'Test Ball',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    );
    expect(ball.baseSpeed, 320.0);
    expect(ball.mass, 1.0);
    expect(ball.imageBytes, isNull);
  });

  test('copyWith overrides only given fields and preserves id', () {
    const ball = CustomBall(
      id: 'a',
      name: 'Original',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    );
    final updated = ball.copyWith(name: 'Renamed', baseSpeed: 400.0);
    expect(updated.id, 'a');
    expect(updated.name, 'Renamed');
    expect(updated.baseSpeed, 400.0);
    expect(updated.primaryColor, Colors.red);
  });

  test('gender defaults to none and survives copyWith', () {
    const ball = CustomBall(
      id: 'a',
      name: 'Original',
      primaryColor: Colors.red,
      glowColor: Colors.pink,
    );
    expect(ball.gender, BallGender.none);
    final female = ball.copyWith(gender: BallGender.female);
    expect(female.gender, BallGender.female);
    expect(female.copyWith(name: 'B').gender, BallGender.female);
  });
}
