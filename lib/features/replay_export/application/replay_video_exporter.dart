import '../../sprites/application/skill_sprite_readiness.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import '../data/video_encoder.dart';
import '../presentation/replay_frame_painter.dart';
import 'replay_audio_mixer.dart';

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

class ExportDurationLimit implements Exception {
  const ExportDurationLimit();
  @override
  String toString() =>
      'This replay exceeds the 10-minute video limit. Confirm a shortened export before rendering.';
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
  static const double finisherSeconds = 2.4;
  // Guard against a match that never ends (none do in practice).
  static const int maxMatchFrames = fps * 60 * 10;

  final VideoEncoder encoder;
  final FrameRasterizer rasterize;

  /// Allows short pipeline tests without encoding ten minutes of frames.
  @visibleForTesting
  final int matchFrameLimit;

  ReplayVideoExporter({
    required this.encoder,
    this.rasterize = rasterizePicture,
    this.matchFrameLimit = maxMatchFrames,
  }) : assert(matchFrameLimit > 0 && matchFrameLimit <= maxMatchFrames);

  /// Encodes the match and returns the video's local path. [onProgress]
  /// receives 0..1; throws [ExportCancelled] once [isCancelled] returns true.
  Future<String> export({
    required List<CustomBall> contestants,
    int simulationRevision = 3,
    required int seed,
    required double arenaRadius,
    double speedMultiplier = 1.0,
    bool automaticSpeedUp = true,
    bool showEffects = true,
    int slowMotionLines = MatchSimulationController.slowMotionLineThreshold,
    double? slowMotionBeforeWinSeconds,
    double ballScale = 1.0,
    MatchMode mode = MatchMode.threads,
    Set<PowerUpKind>? powerUps,
    Set<String>? customSkills,
    List<int> nudgeSteps = const [],
    int? endStep,
    PowerUpConfig tuning = PowerUpConfig.defaults,
    SkillLibrary skillLibrary = SkillLibrary.defaults,
    bool endlessBattle = false,
    bool dualWield = false,
    bool mayhem = false,
    int mayhemSeconds = 120,
    bool shrinkingArena = false,
    double minimumArenaScale = 0.60,
    ReplayStyle style = const ReplayStyle(),
    bool finishersEnabled = true,
    bool randomizedHairstyles = false,
    bool includeBgm = false,
    bool includeSfx = false,
    String bgmAsset = 'assets/sounds/bgm_arena.wav',
    double bgmLevel = 1,
    double sfxLevel = 0.9,
    ValueChanged<double>? onProgress,
    bool Function()? isCancelled,
    Future<bool> Function()? confirmDurationLimit,
  }) async {
    MatchSimulationController newMatch() => MatchSimulationController(
      contestants,
      simulationRevision: simulationRevision,
      arenaRadius: arenaRadius,
      seed: seed,
      arenaBackground: style.background,
      slowMotionLines: slowMotionLines,
      slowMotionBeforeWinSeconds: slowMotionBeforeWinSeconds,
      ballScale: ballScale,
      mode: mode,
      powerUpKinds: powerUps,
      customSkillIds: customSkills,
      nudgeSteps: nudgeSteps,
      endAfterKnockoutStep: endStep,
      tuning: tuning,
      skillLibrary: skillLibrary,
      endlessBattle: endlessBattle,
      dualWield: dualWield,
      mayhem: mayhem,
      mayhemSeconds: mayhemSeconds,
      shrinkingArena: shrinkingArena,
      minimumArenaScale: minimumArenaScale,
      bloodColor: style.bloodColor,
      automaticSpeedUp: automaticSpeedUp,
      arenaDecoration: style.arenaDecoration,
      randomizedHairstyles: randomizedHairstyles,
    );
    final missing = await SkillSpriteReadiness.prepare(
      library: skillLibrary,
      tuning: tuning,
      includeTraps: mode != MatchMode.threads,
      kinds: mode == MatchMode.threads ? const {} : powerUps,
      customIds: mode == MatchMode.threads ? const {} : customSkills,
    );
    if (missing.isNotEmpty) {
      throw StateError(
        'Cannot export: ${missing.length} artwork assets are missing. Open Sprites to reload them, then retry.',
      );
    }
    final frameDelta = speedMultiplier / fps;

    // Dry run (no rendering) to know the total frame count for progress.
    final dryRun = newMatch();
    final audioEvents = <ReplaySoundEvent>[];
    final audioRecorder = _ReplaySoundRecorder(audioEvents);
    var matchFrames = 0;
    while (dryRun.state.status != MatchStatus.finished &&
        matchFrames < matchFrameLimit) {
      if (isCancelled?.call() ?? false) throw const ExportCancelled();
      dryRun.tick(frameDelta);
      matchFrames++;
      audioRecorder.capture(dryRun, matchFrames / fps);
    }
    final truncated = dryRun.state.status != MatchStatus.finished;
    if (truncated) {
      if (confirmDurationLimit == null) throw const ExportDurationLimit();
      if (!await confirmDurationLimit()) throw const ExportCancelled();
    }
    final holdFrames = truncated ? 0 : (finalHoldSeconds * fps).round();
    final cardFrames = truncated ? 0 : (winnerCardSeconds * fps).round();
    final loserFrames = truncated ? 0 : (loserSeconds * fps).round();
    final finisherFrames =
        !truncated && finishersEnabled && dryRun.winningMove != null
        ? (finisherSeconds * fps).round()
        : 0;
    final totalFrames =
        matchFrames +
        (truncated ? 0 : 1) +
        holdFrames +
        finisherFrames +
        loserFrames +
        cardFrames;

    if (truncated) {
      // A shortened clip has no fabricated knockout, win sound or result card.
    } else if (mayhem) {
      audioEvents.add(ReplaySoundEvent(matchFrames / fps, 'whistle', 0.8));
    } else {
      audioEvents.add(ReplaySoundEvent(matchFrames / fps, 'out', 0.7));
      if (!finishersEnabled) {
        audioEvents.add(
          ReplaySoundEvent(
            (matchFrames + holdFrames + loserFrames) / fps,
            'win',
            0.85,
          ),
        );
      }
    }

    ReplayAudio? audio;
    if ((includeBgm || includeSfx) && encoder is AudioVideoEncoder) {
      audio = await ReplayAudioMixer.mix(
        durationSeconds: totalFrames / fps,
        includeBgm: includeBgm,
        includeSfx: includeSfx,
        bgmAsset: bgmAsset,
        bgmLevel: bgmLevel,
        sfxLevel: sfxLevel,
        events: audioEvents,
      );
    }

    final match = newMatch();
    await match.preloadImages();
    if (mode != MatchMode.threads) await PowerUpSprites.load();
    if (audio != null) {
      await (encoder as AudioVideoEncoder).startWithAudio(
        width: width,
        height: height,
        fps: fps,
        pcm16le: audio.pcm16le,
        sampleRate: audio.sampleRate,
      );
    } else {
      await encoder.start(width: width, height: height, fps: fps);
    }

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
      for (var frame = 0; frame < matchFrames + (truncated ? 0 : 1); frame++) {
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
      final winner = finalState.balls
          .where((b) => b.config.id == finalState.winnerId)
          .firstOrNull;
      for (
        var i = 0;
        i < finisherFrames && winner != null && loser != null;
        i++
      ) {
        await emit(
          (canvas, size) => ReplayFramePainter.paintFinisher(
            canvas,
            size,
            winner,
            loser,
            match.winningMove!,
            i / finisherFrames,
            videoTime: videoTime(),
            style: style,
          ),
        );
      }
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

class _ReplaySoundRecorder {
  _ReplaySoundRecorder(this.events);

  final List<ReplaySoundEvent> events;
  int wallHits = 0;
  int ballHits = 0;
  int threadCuts = 0;
  int knockouts = 0;
  int shots = 0;
  int gatling = 0;
  int hits = 0;
  int slashes = 0;
  int blocks = 0;
  int blasts = 0;
  int pickups = 0;
  final Map<String, int> interactions = {};
  final Map<String, int> skillSounds = {};

  void capture(MatchSimulationController match, double seconds) {
    void changed(int current, int previous, String cue, [double gain = 1]) {
      if (current > previous) events.add(ReplaySoundEvent(seconds, cue, gain));
    }

    changed(match.wallHits, wallHits, 'bounce', 0.45);
    changed(match.ballHits, ballHits, 'collide', 0.6);
    changed(match.threadCuts, threadCuts, 'slash', 0.55);
    changed(match.knockouts, knockouts, 'out', 0.7);
    wallHits = match.wallHits;
    ballHits = match.ballHits;
    threadCuts = match.threadCuts;
    knockouts = match.knockouts;

    final powerUps = match.powerUps;
    if (powerUps == null) return;
    changed(powerUps.gatlingShots, gatling, 'gatling', 0.5);
    if (powerUps.gatlingShots == gatling) {
      changed(
        powerUps.shots,
        shots,
        powerUps.shots - shots >= 5 ? 'shotgun' : 'shot',
        0.55,
      );
    }
    changed(powerUps.hits, hits, 'hit', 0.5);
    changed(powerUps.slashes, slashes, 'slash', 0.55);
    changed(powerUps.blocks, blocks, 'shield', 0.5);
    changed(powerUps.blasts, blasts, 'bomb', 0.75);
    changed(powerUps.pickups, pickups, 'pickup', 0.5);
    shots = powerUps.shots;
    gatling = powerUps.gatlingShots;
    hits = powerUps.hits;
    slashes = powerUps.slashes;
    blocks = powerUps.blocks;
    blasts = powerUps.blasts;
    pickups = powerUps.pickups;

    for (final entry in powerUps.interactionSounds.entries) {
      if (entry.value > (interactions[entry.key] ?? 0)) {
        final cue = switch (entry.key) {
          'warp' => 'pickup',
          'freeze' || 'repel' => 'shield',
          'cut' => 'slash',
          'out' => 'out',
          _ => 'hit',
        };
        events.add(ReplaySoundEvent(seconds, cue, 0.6));
      }
      interactions[entry.key] = entry.value;
    }
    for (final entry in powerUps.skillSounds.entries) {
      if (entry.value > (skillSounds[entry.key] ?? 0) &&
          const {
            'shot',
            'shotgun',
            'gatling',
            'slash',
            'shield',
            'bomb',
            'pickup',
            'hit',
          }.contains(entry.key)) {
        events.add(ReplaySoundEvent(seconds, entry.key, 0.6));
      }
      skillSounds[entry.key] = entry.value;
    }
  }
}
