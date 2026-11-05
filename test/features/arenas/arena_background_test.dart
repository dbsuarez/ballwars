import 'package:ballwars/features/replay_export/presentation/replay_frame_painter.dart';
import 'package:ballwars/features/replay_export/domain/video_visibility.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arenas/domain/arena_definition.dart';
import 'package:ballwars/features/arena_simulation/domain/arena_boundary_geometry.dart';
import 'package:ballwars/features/arena_simulation/domain/floating_text.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

Future<List<int>> corner(
  ArenaDecoration theme,
  ArenaShape shape, {
  bool custom = true,
  Offset point = const Offset(83, 77),
}) async {
  final state = SimulationState(
    balls: const [],
    particles: ParticleSystem(),
    floatingTexts: FloatingTextManager(),
    status: MatchStatus.running,
    winnerId: null,
    arenaRadius: 100,
    arenaShape: shape,
  );
  final recorder = ui.PictureRecorder();
  ArenaPainter(
    state: state,
    arenaRadius: 100,
    rimAngle: 0,
    background: const Color(0xFF000000),
    arenaTitle: '',
    arenaSubtitle: '',
    arenaDecoration: theme,
    arenaPreset: custom
        ? ArenaDefinition(
            id: 'test',
            name: 'Test',
            theme: theme,
            trapTheme: theme,
            floorColor: 0xffcc6644,
          )
        : null,
  ).paint(Canvas(recorder), const Size(240, 240));
  final picture = recorder.endRecording();
  final image = await picture.toImage(240, 240);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  // World (83,77) is inside a square and outside its inscribed circle.
  final index =
      ((120 + point.dy * 240 / 220).round() * 240 +
          (120 + point.dx * 240 / 220).round()) *
      4;
  final pixel = bytes.sublist(index, index + 4);
  image.dispose();
  picture.dispose();
  return pixel;
}

void main() {
  test(
    'video rendering retains a custom arena snapshot through visibility choices',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const arena = ArenaDefinition(
        id: 'video-map',
        name: 'Video map',
        floorColor: 0xffcc6644,
      );
      final state = SimulationState(
        balls: const [],
        particles: ParticleSystem(),
        floatingTexts: FloatingTextManager(),
        status: MatchStatus.running,
        winnerId: null,
        arenaRadius: 100,
        arenaShape: ArenaShape.square,
      );
      Future<int> orangePixels(ReplayStyle style) async {
        final recorder = ui.PictureRecorder();
        ReplayFramePainter.paintMatch(
          Canvas(recorder),
          const Size(320, 640),
          state,
          100,
          videoTime: 1,
          style: style,
        );
        final pic = recorder.endRecording();
        final image = await pic.toImage(320, 640);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        var count = 0;
        for (var i = 0; i < bytes.length; i += 4) {
          if (bytes[i] > 150 &&
              bytes[i + 1] > 60 &&
              bytes[i + 1] < 140 &&
              bytes[i + 2] < 110) {
            count++;
          }
        }
        image.dispose();
        pic.dispose();
        return count;
      }

      final style = const ReplayStyle(
        arenaPreset: arena,
        background: Color(0xff000000),
        arenaTitle: '',
        arenaSubtitle: '',
      ).forVideo(const VideoVisibility());
      expect(style.arenaPreset, same(arena));
      expect(await orangePixels(style), greaterThan(500));
      expect(
        await orangePixels(
          const ReplayStyle(arenaTitle: '', arenaSubtitle: ''),
        ),
        0,
      );
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  for (final theme in ArenaDecoration.values) {
    test('${theme.name} fills square corners and masks circles', () async {
      final square = await corner(theme, ArenaShape.square);
      expect(square[3], 255);
      expect(square[0], greaterThan(65), reason: 'custom floor covers corners');
      final circle = await corner(theme, ArenaShape.circle);
      expect(circle[3], 0, reason: 'the circle mask excludes square corners');
    });
  }
  test(
    'built-in desert corners have desert artwork rather than a black cutout',
    () async {
      expect(
        (await corner(
          ArenaDecoration.desert,
          ArenaShape.square,
          custom: false,
        ))[0],
        greaterThan(100),
      );
    },
  );
  test(
    'default grid reaches square corners rather than retaining circular chords',
    () async {
      final pixel = await corner(
        ArenaDecoration.defaultArena,
        ArenaShape.square,
        custom: false,
        point: const Offset(87.5, 62.5),
      );
      expect(pixel[0], greaterThan(2));
    },
  );

  test('laser endpoints reach every square wall and follow shrinkage', () {
    for (final radius in [100.0, 60.0]) {
      for (final angle in [0.0, math.pi / 4, 1.1]) {
        final (a, b) = arenaGateSegment(angle, radius, ArenaShape.square);
        expect(math.max(b.dx.abs(), b.dy.abs()), closeTo(radius, 1e-8));
        expect(a, -b);
        final (_, circle) = arenaGateSegment(angle, radius, ArenaShape.circle);
        expect(circle.distance, closeTo(radius, 1e-8));
      }
    }
  });
  test('square laser artwork reaches the diagonal corner', () async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..translate(130, 130);
    PowerUpPainter.paintArenaThemeHazard(
      canvas,
      ArenaThemeHazard(
        kind: ArenaThemeHazardKind.laserGate,
        position: Offset.zero,
        spawnStep: 0,
        angle: math.pi / 4,
      ),
      100,
      6,
      30,
      shape: ArenaShape.square,
    );
    final pic = rec.endRecording();
    final image = await pic.toImage(260, 260);
    final bytes = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    expect(bytes[(224 * 260 + 224) * 4 + 3], greaterThan(0));
    image.dispose();
    pic.dispose();
  });
}
