import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../data/video_encoder.dart';
import '../presentation/replay_frame_painter.dart';

/// Renders a picture into `width * height * 4` bytes of RGBA.
typedef FrameRasterizer =
    Future<Uint8List> Function(ui.Picture picture, int width, int height);

Future<Uint8List> rasterizePicture(
  ui.Picture picture,
  int width,
  int height,
) async {
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
  // Same beat the app pauses for after the last line is cut.
  static const double finalHoldSeconds = 1.2;
  static const double winnerCardSeconds = 2.5;
  // The runner-up shown big before the winner card (as in the app).
  static const double loserSeconds = 1.8;
  // Guard against a match that never ends (none do in practice).
  static const int maxMatchFrames = fps * 60 * 10;

  final VideoEncoder encoder;
  final FrameRasterizer rasterize;

  ReplayVideoExporter({
    required this.encoder,
    this.rasterize = rasterizePicture,
  });

  /// Encodes the match and returns the video's local path. [onProgress]
  /// receives 0..1; throws [ExportCancelled] once [isCancelled] returns true.
  Future<String> export({
    required List<CustomBall> contestants,
    required int seed,
    required double arenaRadius,
    double speedMultiplier = 1.0,
    bool showEffects = true,
    int slowMotionLines = MatchSimulationController.slowMotionLineThreshold,
    double? slowMotionBeforeWinSeconds,
    double ballScale = 1.0,
    MatchMode mode = MatchMode.threads,
    Set<PowerUpKind>? powerUps,
    PowerUpConfig tuning = PowerUpConfig.defaults,
    bool endlessBattle = false,
    bool dualWield = false,
    bool mayhem = false,
    int mayhemSeconds = 120,
    bool shrinkingArena = false,
    double minimumArenaScale = 0.60,
    ReplayStyle style = const ReplayStyle(),
    ValueChanged<double>? onProgress,
    bool Function()? isCancelled,
  }) async {
    MatchSimulationController newMatch() => MatchSimulationController(
      contestants,
      arenaRadius: arenaRadius,
      seed: seed,
      arenaBackground: style.background,
      slowMotionLines: slowMotionLines,
      slowMotionBeforeWinSeconds: slowMotionBeforeWinSeconds,
      ballScale: ballScale,
      mode: mode,
      powerUpKinds: powerUps,
      tuning: tuning,
      endlessBattle: endlessBattle,
      dualWield: dualWield,
      mayhem: mayhem,
      mayhemSeconds: mayhemSeconds,
      shrinkingArena: shrinkingArena,
      minimumArenaScale: minimumArenaScale,
      bloodColor: style.bloodColor,
    );
    final frameDelta = speedMultiplier / fps;

    // Dry run (no rendering) to know the total frame count for progress.
    final dryRun = newMatch();
    var matchFrames = 0;
    while (dryRun.state.status != MatchStatus.finished &&
        matchFrames < maxMatchFrames) {
      dryRun.tick(frameDelta);
      matchFrames++;
    }
    final holdFrames = (finalHoldSeconds * fps).round();
    final cardFrames = (winnerCardSeconds * fps).round();
    final loserFrames = (loserSeconds * fps).round();
    final totalFrames = matchFrames + 1 + holdFrames + loserFrames + cardFrames;

    final match = newMatch();
    await match.preloadImages();
    if (mode != MatchMode.threads) await PowerUpSprites.load();
    await encoder.start(width: width, height: height, fps: fps);

    var written = 0;
    // Seconds into the video for the frame being drawn (moves the watermark).
    double videoTime() => written / fps;
    Future<void> emit(
      void Function(ui.Canvas canvas, ui.Size size) paint,
    ) async {
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
        await emit(
          (canvas, size) => ReplayFramePainter.paintMatch(
            canvas,
            size,
            state,
            match.arenaRadius,
            worldRadius: arenaRadius,
            videoTime: videoTime(),
            showEffects: showEffects,
            style: style,
          ),
        );
        if (frame < matchFrames) match.tick(frameDelta);
      }

      final finalState = match.state;
      for (var i = 0; i < holdFrames; i++) {
        match.tick(frameDelta); // the match is over; only the last sparks move
        await emit(
          (canvas, size) => ReplayFramePainter.paintMatch(
            canvas,
            size,
            finalState,
            match.arenaRadius,
            worldRadius: arenaRadius,
            videoTime: videoTime(),
            showEffects: showEffects,
            style: style,
          ),
        );
      }

      final loser = finalState.balls
          .where((b) => b.config.id == match.lastEliminatedId)
          .firstOrNull;
      for (var i = 0; i < loserFrames && loser != null; i++) {
        match.tick(frameDelta);
        await emit(
          (canvas, size) => ReplayFramePainter.paintLoser(
            canvas,
            size,
            finalState,
            match.arenaRadius,
            loser,
            i / loserFrames,
            worldRadius: arenaRadius,
            videoTime: videoTime(),
            showEffects: showEffects,
            style: style,
          ),
        );
      }

      final winner = finalState.balls
          .where((b) => b.config.id == finalState.winnerId)
          .firstOrNull;
      for (var i = 0; i < cardFrames && winner != null; i++) {
        await emit(
          (canvas, size) =>
              // Same number the in-app timer and winner card show.
              ReplayFramePainter.paintWinnerCard(
                canvas,
                size,
                winner,
                match.elapsedSeconds,
                videoTime: videoTime(),
                style: style,
              ),
        );
      }

      return await encoder.finish();
    } catch (_) {
      await encoder.cancel();
      rethrow;
    }
  }
}
