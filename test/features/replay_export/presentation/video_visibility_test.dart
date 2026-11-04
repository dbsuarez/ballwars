import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/video_visibility.dart';
import 'package:ballwars/features/replay_export/presentation/replay_frame_painter.dart';
import 'package:ballwars/features/replay_export/presentation/export_video_dialog.dart';
import 'package:ballwars/features/replay_export/data/video_encoder.dart';

class _Backend implements VideoEncoder, VideoSaver {
  @override
  Future<void> start({
    required int width,
    required int height,
    required int fps,
  }) async {}
  @override
  Future<void> addFrame(Uint8List rgba) async {}
  @override
  Future<String> finish() async => 'video.mp4';
  @override
  Future<void> cancel() async {}
  @override
  String get savedMessage => 'Saved';
  @override
  Future<String> save(String path) async => path;
  @override
  Future<void> share(String path) async {}
}

List<CustomBall> balls(String name) => [
  CustomBall(
    id: 'a',
    name: name,
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  const CustomBall(
    id: 'b',
    name: 'Opponent',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];

Future<Uint8List> frame(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(180, 320);
  try {
    return (await image.toByteData())!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  testWidgets(
    'hidden profile pictures cannot leak into arena or winner frames',
    (tester) async {
      await tester.runAsync(() async {
        Future<ui.Image> image(Color color) async {
          final recorder = ui.PictureRecorder();
          Canvas(
            recorder,
          ).drawRect(const Rect.fromLTWH(0, 0, 20, 20), Paint()..color = color);
          final picture = recorder.endRecording();
          final result = await picture.toImage(20, 20);
          picture.dispose();
          return result;
        }

        final red = await image(Colors.red), green = await image(Colors.green);
        try {
          final match = MatchSimulationController(
            balls('A'),
            arenaRadius: 260,
            seed: 2,
          );
          for (final winner in [false, true]) {
            Future<Uint8List> render(ReplayStyle style) => frame((canvas) {
              if (winner) {
                ReplayFramePainter.paintWinnerCard(
                  canvas,
                  const Size(180, 320),
                  match.state.balls.first,
                  10,
                  videoTime: 1,
                  style: style,
                );
              } else {
                ReplayFramePainter.paintMatch(
                  canvas,
                  const Size(180, 320),
                  match.state,
                  260,
                  videoTime: 1,
                  style: style,
                );
              }
            });
            const hidden = ReplayStyle(visibility: VideoVisibility(layers: {}));
            const visible = ReplayStyle(
              visibility: VideoVisibility(layers: {VideoLayer.pictures}),
            );
            match.state.balls.first.cachedUiImage = red;
            final hiddenRed = await render(hidden),
                visibleRed = await render(visible);
            match.state.balls.first.cachedUiImage = green;
            expect(await render(hidden), orderedEquals(hiddenRed));
            expect(await render(visible), isNot(orderedEquals(visibleRed)));
          }
        } finally {
          red.dispose();
          green.dispose();
        }
      });
    },
  );

  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  test(
    'visibility serializes explicit all-hidden choices and preserves live style',
    () {
      const options = VideoVisibility(watchingLayout: true, layers: {});
      final restored = VideoVisibility.fromJson(options.toJson());
      expect(restored.layers, isEmpty);
      expect(restored.watchingLayout, isTrue);
      const live = ReplayStyle(
        showHpBars: true,
        look: BallLook.pictures,
        arenaTitle: 'Live title',
      );
      final exported = live.forVideo(options);
      expect(live.visibility.shows(VideoLayer.pictures), isTrue);
      expect(live.showHpBars, isTrue);
      expect(exported.visibility.layers, isEmpty);
      expect(exported.arenaTitle, 'Live title');
      expect(exported.watermarkText, "cha0s' Balls");
    },
  );

  testWidgets('names are absent from arena and closing scenes when hidden', (
    tester,
  ) async {
    final a = MatchSimulationController(
      balls('Private name'),
      arenaRadius: 260,
      seed: 2,
    );
    final b = MatchSimulationController(balls('X'), arenaRadius: 260, seed: 2);
    const hidden = ReplayStyle(
      visibility: VideoVisibility(
        watchingLayout: true,
        layers: {VideoLayer.pictures},
      ),
    );
    const visible = ReplayStyle(
      visibility: VideoVisibility(layers: {VideoLayer.names}),
    );
    const size = Size(180, 320);
    for (final scene in ['arena', 'winner', 'loser', 'finisher']) {
      Future<Uint8List> render(
        MatchSimulationController match,
        ReplayStyle style,
      ) => frame((canvas) {
        final first = match.state.balls.first, second = match.state.balls.last;
        switch (scene) {
          case 'arena':
            ReplayFramePainter.paintMatch(
              canvas,
              size,
              match.state,
              260,
              videoTime: 1,
              style: style,
            );
          case 'winner':
            ReplayFramePainter.paintWinnerCard(
              canvas,
              size,
              first,
              10,
              videoTime: 1,
              style: style,
            );
          case 'loser':
            ReplayFramePainter.paintLoser(
              canvas,
              size,
              match.state,
              260,
              second,
              .5,
              videoTime: 1,
              style: style,
            );
          case 'finisher':
            ReplayFramePainter.paintFinisher(
              canvas,
              size,
              first,
              second,
              'Pistol',
              .5,
              videoTime: 1,
              style: style,
            );
        }
      });
      expect(
        await tester.runAsync(() => render(a, hidden)),
        orderedEquals((await tester.runAsync(() => render(b, hidden)))!),
        reason: scene,
      );
      if (scene == 'arena' || scene == 'winner' || scene == 'finisher') {
        expect(
          await tester.runAsync(() => render(a, visible)),
          isNot(
            orderedEquals((await tester.runAsync(() => render(b, visible)))!),
          ),
          reason: '$scene must actually test visible text',
        );
      }
    }
  });

  testWidgets(
    'phone export has grouped visibility/audio choices without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = _Backend();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ExportVideoDialog(
                    contestants: balls('A'),
                    seed: 2,
                    arenaRadius: 260,
                    speedMultiplier: 1,
                    encoder: backend,
                    saver: backend,
                  ),
                ),
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.text('Ball names'), findsOneWidget);
      await tester.tap(find.text('Audio'));
      await tester.pumpAndSettle();
      expect(find.text('Background music'), findsOneWidget);
      expect(find.text('Sound effects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
