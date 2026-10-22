import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/replay_export/presentation/replay_frame_painter.dart';

void main() {
  testWidgets('paints match frames (including slow motion) and the winner card', (tester) async {
    final controller = MatchSimulationController(const [
      CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
      CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
    ], arenaRadius: 260, seed: 2);
    const size = Size(360, 640);

    void paint(void Function(Canvas canvas) draw) {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      recorder.endRecording().dispose();
    }

    paint((canvas) => ReplayFramePainter.paintMatch(canvas, size, controller.state, 260));
    var sawSlowMotion = false;
    while (controller.state.status != MatchStatus.finished) {
      controller.tick(1 / 30);
      if (controller.state.status == MatchStatus.slowMotion && !sawSlowMotion) {
        sawSlowMotion = true;
        paint((canvas) => ReplayFramePainter.paintMatch(canvas, size, controller.state, 260));
      }
    }
    final winner = controller.state.balls.firstWhere((b) => b.config.id == controller.state.winnerId);
    paint((canvas) => ReplayFramePainter.paintWinnerCard(canvas, size, winner, controller.elapsedSeconds));
  });
}
