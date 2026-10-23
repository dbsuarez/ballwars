// Rough paint benchmark: plays a 4-ball match and paints/rasterizes frames
// with ArenaPainter, so drawing changes can be compared before and after.
//   flutter test tool/bench/paint_bench_test.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  test('paint benchmark', () async {
    final balls = [
      for (var i = 0; i < 4; i++)
        CustomBall(id: 'b$i', name: 'B$i', primaryColor: Colors.primaries[i * 3], glowColor: Colors.white),
    ];
    const side = 720.0;
    final c = MatchSimulationController(balls, arenaRadius: 300, seed: 5, slowMotionLines: 0);
    final paintWatch = Stopwatch();
    final rasterWatch = Stopwatch();
    var frames = 0;
    for (var i = 0; i < 400 && c.state.status != MatchStatus.finished; i++) {
      c.tick(1 / 60);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      paintWatch.start();
      ArenaPainter(state: c.state, arenaRadius: 300, rimAngle: 0).paint(canvas, const Size(side, side));
      final picture = recorder.endRecording();
      paintWatch.stop();
      if (i % 4 == 0) {
        rasterWatch.start();
        final image = await picture.toImage(side.toInt(), side.toInt());
        rasterWatch.stop();
        image.dispose();
      }
      picture.dispose();
      frames++;
    }
    // ignore: avoid_print
    print('frames=$frames  record ${(paintWatch.elapsedMicroseconds / frames / 1000).toStringAsFixed(3)} ms/frame  '
        'raster ${(rasterWatch.elapsedMicroseconds / (frames / 4) / 1000).toStringAsFixed(2)} ms/frame');
  });
}
