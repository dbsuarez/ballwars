import 'package:ballwars/features/match_setup/domain/arena_rotation.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/video_visibility.dart';
import 'package:ballwars/features/replay_export/presentation/replay_frame_painter.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/replay_export/application/replay_video_exporter.dart';
import 'package:ballwars/features/replay_export/data/video_encoder.dart';

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

class _FakeEncoder implements VideoEncoder {
  int? width, height, fps;
  int frames = 0;
  bool finished = false;
  bool cancelled = false;

  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
  }) async {
    this.width = width;
    this.height = height;
    this.fps = fps;
  }

  @override
  Future<void> addFrame(Uint8List rgba) async {
    expect(rgba.length, width! * height! * 4);
    frames++;
  }

  @override
  Future<String> finish() async {
    finished = true;
    return '/tmp/replay.mp4';
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

class _FakeAudioEncoder extends _FakeEncoder implements AudioVideoEncoder {
  Uint8List? audio;
  int? audioRate;

  @override
  Future<void> startWithAudio({
    required int width,
    required int height,
    required int fps,
    required Uint8List pcm16le,
    required int sampleRate,
  }) async {
    this.width = width;
    this.height = height;
    this.fps = fps;
    audio = pcm16le;
    audioRate = sampleRate;
  }
}

// Skips GPU rasterization; the encoder only checks the byte count.
Future<Uint8List> _fakeRasterize(
  ui.Picture picture,
  int width,
  int height,
) async => Uint8List(width * height * 4);

/// Frames a live match takes at [fps], played to the end.
int _matchFrames(int seed, int fps) {
  final c = MatchSimulationController(_balls, arenaRadius: 260, seed: seed);
  var frames = 0;
  while (c.state.status != MatchStatus.finished) {
    c.tick(1 / fps);
    frames++;
  }
  return frames;
}

void main() {
  testWidgets('export frame after rotation equals the live post-transition frame', (tester) async {
    await tester.runAsync(() async {
      final contestants = List.generate(6, (i) => CustomBall(id: 'b$i', name: 'Ball $i', primaryColor: Colors.primaries[i], glowColor: Colors.primaries[i]));
      const rotation = ArenaRotation(rotateThemes: true, rotateShapes: true, intervalSeconds: 30);
      const style = ReplayStyle(visibility: VideoVisibility(watchingLayout: true, layers: {}));
      final live = MatchSimulationController(contestants, seed: 2, arenaRadius: 260,
        simulationRevision: 7, mode: MatchMode.arsenal, mayhem: true, mayhemSeconds: 90,
        endlessBattle: true, powerUpKinds: {}, customSkillIds: {}, arenaRotation: rotation);
      for (var i = 0; i < 930; i++) { live.tick(1 / 30); }
      expect(live.state.arenaShape, ArenaShape.square);
      Future<Uint8List> pixels(ui.Picture picture) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder)..scale(.25)..drawPicture(picture);
        final scaled = recorder.endRecording();
        final image = await scaled.toImage(180, 320);
        try { return (await image.toByteData())!.buffer.asUint8List(); }
        finally { image.dispose(); scaled.dispose(); }
      }
      final recorder = ui.PictureRecorder();
      ReplayFramePainter.paintMatch(Canvas(recorder), const Size(720, 1280), live.state, live.arenaRadius,
        worldRadius: 260, arenaDecoration: live.arenaDecoration, controller: live,
        videoTime: 31, style: style);
      final picture = recorder.endRecording();
      final expected = await pixels(picture); picture.dispose();
      final scratch = Uint8List(720 * 1280 * 4);
      Uint8List? actual;
      var frame = 0;
      final encoder = _FakeEncoder();
      final exporter = ReplayVideoExporter(encoder: encoder, matchFrameLimit: 931,
        rasterize: (picture, width, height) async {
          if (frame++ == 930) actual = await pixels(picture);
          return scratch;
        });
      await exporter.export(contestants: contestants, seed: 2, arenaRadius: 260,
        simulationRevision: 7, mode: MatchMode.arsenal, mayhem: true, mayhemSeconds: 90,
        endlessBattle: true, powerUps: {}, customSkills: {}, arenaRotation: rotation,
        style: style, confirmDurationLimit: () async => true);
      expect(actual, orderedEquals(expected));
    });
  });

  test(
    'arena-only export omits closing cards without changing match duration',
    () async {
      final encoder = _FakeEncoder();
      final exporter = ReplayVideoExporter(
        encoder: encoder,
        rasterize: _fakeRasterize,
      );
      await exporter.export(
        contestants: _balls,
        seed: 2,
        arenaRadius: 260,
        style: const ReplayStyle(
          visibility: VideoVisibility(watchingLayout: true, layers: {}),
        ),
      );
      expect(
        encoder.frames,
        _matchFrames(2, ReplayVideoExporter.fps) +
            1 +
            (ReplayVideoExporter.finalHoldSeconds * ReplayVideoExporter.fps)
                .round(),
      );
      expect(encoder.finished, isTrue);
    },
  );

  for (final consent in <bool?>[null, false, true]) {
    test(
      'long video requires confirmation before encoding ($consent)',
      () async {
        final encoder = _FakeEncoder();
        final exporter = ReplayVideoExporter(
          encoder: encoder,
          rasterize: _fakeRasterize,
          matchFrameLimit: 3,
        );
        var asked = false;
        final result = exporter.export(
          contestants: _balls,
          seed: 1,
          arenaRadius: 260,
          confirmDurationLimit: consent == null
              ? null
              : () async {
                  expect(encoder.width, isNull);
                  expect(encoder.frames, 0);
                  asked = true;
                  return consent;
                },
        );
        if (consent == true) {
          expect(await result, '/tmp/replay.mp4');
          expect(encoder.frames, 3);
          expect(encoder.finished, isTrue);
        } else {
          await expectLater(
            result,
            throwsA(
              consent == null
                  ? isA<ExportDurationLimit>()
                  : isA<ExportCancelled>(),
            ),
          );
          expect(encoder.width, isNull);
          expect(encoder.frames, 0);
        }
        expect(asked, consent != null);
      },
    );
  }
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mixes selected replay audio into an audio-capable encoder', () async {
    final encoder = _FakeAudioEncoder();
    await ReplayVideoExporter(
      encoder: encoder,
      rasterize: _fakeRasterize,
    ).export(contestants: _balls, seed: 4, arenaRadius: 260, includeSfx: true);

    expect(encoder.audioRate, 22050);
    expect(encoder.audio, isNotNull);
    expect(encoder.audio!, isNot(everyElement(0)));
  });

  test(
    'renders every match frame, the final hold and the winner card, then finishes',
    () async {
      final encoder = _FakeEncoder();
      final progress = <double>[];

      final path =
          await ReplayVideoExporter(
            encoder: encoder,
            rasterize: _fakeRasterize,
          ).export(
            contestants: _balls,
            seed: 4,
            arenaRadius: 260,
            onProgress: progress.add,
          );

      const fps = ReplayVideoExporter.fps;
      final expected =
          _matchFrames(4, fps) +
          1 +
          (ReplayVideoExporter.finalHoldSeconds * fps).round() +
          (ReplayVideoExporter.finisherSeconds * fps).round() +
          (ReplayVideoExporter.loserSeconds * fps).round() +
          (ReplayVideoExporter.winnerCardSeconds * fps).round();
      expect(path, '/tmp/replay.mp4');
      expect(encoder.finished, isTrue);
      expect((encoder.width, encoder.height, encoder.fps), (720, 1280, 30));
      expect(encoder.frames, expected);
      expect(progress.last, 1.0);
    },
  );

  test('cancelling stops the export and discards the video', () async {
    final encoder = _FakeEncoder();

    final export =
        ReplayVideoExporter(encoder: encoder, rasterize: _fakeRasterize).export(
          contestants: _balls,
          seed: 4,
          arenaRadius: 260,
          isCancelled: () => encoder.frames >= 10,
        );

    await expectLater(export, throwsA(isA<ExportCancelled>()));
    expect(encoder.frames, 10);
    expect(encoder.cancelled, isTrue);
    expect(encoder.finished, isFalse);
  });

  test(
    'a replay ends exactly like the live match, whatever the frame rate',
    () {
      for (final seed in [1, 2, 3, 4, 5]) {
        MatchSimulationController play(double frameDelta) {
          final c = MatchSimulationController(
            _balls,
            arenaRadius: 260,
            seed: seed,
          );
          while (c.state.status != MatchStatus.finished) {
            c.tick(frameDelta);
          }
          return c;
        }

        final live = play(1 / 144); // a fast phone screen
        final video = play(1 / ReplayVideoExporter.fps);
        expect(video.state.winnerId, live.state.winnerId);
        for (var i = 0; i < live.state.balls.length; i++) {
          expect(video.state.balls[i].position, live.state.balls[i].position);
        }
      }
    },
  );
}
