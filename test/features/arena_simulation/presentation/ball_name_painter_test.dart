import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_name_painter.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/replay_export/domain/video_visibility.dart';
import 'package:ballwars/features/replay_export/presentation/replay_frame_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'names follow below balls and remain inside the visible frame at edges',
    () {
      final match = MatchSimulationController(
        LocalBallRepository.presets.take(2).toList(),
        arenaRadius: 100,
        lookAhead: false,
      );
      final ball = match.state.balls.first..position = Offset.zero;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final center = BallNamePainter.paint(
        canvas,
        ball,
        const Size(220, 220),
        1,
      );
      expect(center.top, greaterThan(ball.radius));
      expect(center.center.dx, 0);
      ball.position = const Offset(99, 99);
      final edge = BallNamePainter.paint(
        canvas,
        ball,
        const Size(220, 220),
        1,
        score: '100/100',
      );
      expect(edge.right, lessThanOrEqualTo(110));
      expect(edge.bottom, lessThanOrEqualTo(110));
      rec.endRecording().dispose();
    },
  );
  test('name preference round-trips and invalid values are rejected', () {
    final presets = LocalBallRepository.presets;
    final link = ReplayLink(
      contestants: presets.take(2).toList(),
      seed: 1,
      speedMultiplier: 1,
      showBallNames: true,
    );
    final uri = link.toUri(presetIds: {for (final b in presets) b.id});
    expect(ReplayLink.fromUri(uri, presets: presets)!.showBallNames, true);
    expect(
      ReplayLink.fromUri(
        uri.replace(queryParameters: {...uri.queryParameters, 'names': 'true'}),
        presets: presets,
      ),
      isNull,
    );
  });
  test(
    'video Names switch hides attached names without changing live style',
    () async {
      final match = MatchSimulationController(
        LocalBallRepository.presets.take(2).toList(),
        arenaRadius: 200,
        lookAhead: false,
      );
      Future<List<int>> frame(bool names, Set<VideoLayer> layers) async {
        final rec = ui.PictureRecorder();
        ReplayFramePainter.paintMatch(
          Canvas(rec),
          const Size(360, 640),
          match.state,
          200,
          videoTime: 0,
          style: ReplayStyle(
            showBallNames: names,
            visibility: VideoVisibility(layers: layers),
          ),
        );
        final picture = rec.endRecording();
        final image = await picture.toImage(360, 640);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List().toList();
        image.dispose();
        picture.dispose();
        return bytes;
      }

      expect(await frame(true, {}), await frame(false, {}));
      expect(
        await frame(true, {VideoLayer.names}),
        isNot(await frame(false, {VideoLayer.names})),
      );
      const live = ReplayStyle(showBallNames: true);
      expect(
        live.forVideo(const VideoVisibility(layers: {})).showBallNames,
        true,
      );
    },
  );
}
