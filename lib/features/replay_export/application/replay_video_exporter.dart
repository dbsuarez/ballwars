import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../data/video_encoder.dart';
import '../presentation/replay_frame_painter.dart';

/// Renders a picture into `width * height * 4` bytes of RGBA.
typedef FrameRasterizer = Future<Uint8List> Function(ui.Picture picture, int width, int height);

Future<Uint8List> rasterizePicture(ui.Picture picture, int width, int height) async {
  final image = await picture.toImage(width, height);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class ExportCancelled implements Exception {
  const ExportCancelled();
}

/// Re-runs a match from its seed off-screen and encodes it as a 9:16 video.
/// Matches are deterministic, so the video shows exactly the match that was
/// played, whatever the frame rate it was watched at.
class ReplayVideoExporter {
  static const int width = 720;
  static const int height = 1280;
  static const int fps = 30;
  static const double finalHoldSeconds = 0.6;
  static const double winnerCardSeconds = 2.5;
  // Guard against a match that never ends (none do in practice).
  static const int maxMatchFrames = fps * 60 * 10;

  final VideoEncoder encoder;
  final FrameRasterizer rasterize;

  ReplayVideoExporter({required this.encoder, this.rasterize = rasterizePicture});

  /// Encodes the match and returns the video's local path. [onProgress]
  /// receives 0..1; throws [ExportCancelled] once [isCancelled] returns true.
  Future<String> export({
    required List<CustomBall> contestants,
    required int seed,
    required double arenaRadius,
    double speedMultiplier = 1.0,
    ValueChanged<double>? onProgress,
    bool Function()? isCancelled,
  }) async {
    MatchSimulationController newMatch() =>
        MatchSimulationController(contestants, arenaRadius: arenaRadius, seed: seed);
    final frameDelta = speedMultiplier / fps;

    // Dry run (no rendering) to know the total frame count for progress.
    final dryRun = newMatch();
    var matchFrames = 0;
    while (dryRun.state.status != MatchStatus.finished && matchFrames < maxMatchFrames) {
      dryRun.tick(frameDelta);
      matchFrames++;
    }
    final holdFrames = (finalHoldSeconds * fps).round();
    final cardFrames = (winnerCardSeconds * fps).round();
    final totalFrames = matchFrames + 1 + holdFrames + cardFrames;

    final match = newMatch();
    await match.preloadImages();
    await encoder.start(width: width, height: height, fps: fps);

    var written = 0;
    Future<void> emit(void Function(ui.Canvas canvas, ui.Size size) paint) async {
      if (isCancelled?.call() ?? false) throw const ExportCancelled();
      final recorder = ui.PictureRecorder();
      paint(ui.Canvas(recorder), const ui.Size(width + 0.0, height + 0.0));
      final picture = recorder.endRecording();
      try {
        await encoder.addFrame(await rasterize(picture, width, height));
      } finally {
        picture.dispose();
      }
      written++;
      onProgress?.call(written / totalFrames);
    }

    try {
      for (var frame = 0; frame <= matchFrames; frame++) {
        final state = match.state;
        await emit((canvas, size) => ReplayFramePainter.paintMatch(canvas, size, state, arenaRadius));
        if (frame < matchFrames) match.tick(frameDelta);
      }

      final finalState = match.state;
      for (var i = 0; i < holdFrames; i++) {
        await emit((canvas, size) => ReplayFramePainter.paintMatch(canvas, size, finalState, arenaRadius));
      }

      final winner = finalState.balls.where((b) => b.config.id == finalState.winnerId).firstOrNull;
      for (var i = 0; i < cardFrames && winner != null; i++) {
        await emit((canvas, size) =>
            // Same number the in-app timer and winner card show.
            ReplayFramePainter.paintWinnerCard(canvas, size, winner, match.elapsedSeconds));
      }

      return await encoder.finish();
    } catch (_) {
      await encoder.cancel();
      rethrow;
    }
  }
}
