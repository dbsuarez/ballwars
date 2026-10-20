import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('paint runs without throwing for a live simulation state', () async {
    final controller = MatchSimulationController(
      const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
      arenaRadius: 260.0,
      seed: 1,
    );
    controller.tick(1 / 60);

    final painter = ArenaPainter(
      state: controller.state,
      arenaRadius: 260.0,
      rimAngle: 0.5,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, const Size(520, 520));
    final picture = recorder.endRecording();
    expect(picture, isNotNull);
  });
}
