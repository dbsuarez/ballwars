// Explicit runtime capture: flutter test test/visual/capture_battle_ui.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/winner_modal.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/replay_export/presentation/saved_replays_screen.dart';
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
  Future<String> finish() async => 'unused.mp4';
  @override
  Future<void> cancel() async {}
  @override
  String get savedMessage => 'Saved';
  @override
  Future<String> save(String path) async => path;
  @override
  Future<void> share(String path) async {}
}

void main() {
  testWidgets(
    'Phase D screens preserve arena area and reachable result actions',
    (tester) async {
      final previous = OfflineStore.instance;
      OfflineStore.instance = MemoryOfflineStore();
      addTearDown(() => OfflineStore.instance = previous);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final font in [
        ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
        ('JetBrains Mono', 'assets/fonts/JetBrainsMono-Medium.ttf'),
        ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
      }
      await tester.runAsync(() => PowerUpSprites.load());
      final balls = List.generate(
        8,
        (i) => CustomBall(
          id: 'fighter$i',
          name: [
            'Crimson',
            'Volt',
            'Phantom',
            'Blaze',
            'Frost',
            'Jade',
            'Nova',
            'Onyx',
          ][i],
          primaryColor: [
            Colors.redAccent,
            Colors.cyan,
            Colors.purpleAccent,
            Colors.amber,
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.grey,
          ][i],
          glowColor: Colors.cyan,
        ),
      );
      await SavedReplayStore.add(
        Uri.parse('https://example.com/?seed=42'),
        contestantNames: ['Crimson', 'Volt'],
      );
      await SavedReplayStore.rename(
        (await SavedReplayStore.load()).single.id,
        'Crimson vs Volt - Final round',
      );
      final key = GlobalKey();
      Future<void> capture(String name) async {
        await tester.pump();
        expect(tester.takeException(), isNull, reason: name);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/phase-d-screenshots').create(recursive: true);
          await File(
            'build/phase-d-screenshots/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> mount(Widget child, {bool settle = true}) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(AppPalettes.midnight),
              builder: (_, child) => AppFrame(child: child!),
              home: child,
            ),
          ),
        );
        if (settle) await tester.pumpAndSettle();
      }

      for (final size in [
        const Size(360, 800),
        const Size(800, 360),
        const Size(440, 900),
      ]) {
        tester.view.physicalSize = size;
        final suffix = '${size.width.toInt()}x${size.height.toInt()}';
        await mount(
          ArenaBattleScreen(
            config: MatchConfig(
              contestants: balls,
              mode: MatchMode.arsenal,
              mayhem: true,
            ),
            seed: 42,
          ),
          settle: false,
        );
        for (var i = 0; i < 45; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byTooltip('Pause').hitTestable(), findsOneWidget);
        await tester.tap(find.byTooltip('Pause'));
        await tester.pump();
        if (size.height > size.width) {
          expect(
            tester
                .getSize(find.byKey(const ValueKey('arena-priority-square')))
                .width,
            size.width,
          );
        }
        await capture('battle-$suffix');
        await mount(
          Scaffold(
            body: WinnerModal(
              winner: balls.first,
              durationSeconds: 120,
              winningMove: 'Rocket Launcher',
              showEffects: false,
              mayhemTally: [
                for (var i = 0; i < balls.length; i++)
                  (balls[i], 8 - i, i, 100.0 - i * 7),
              ],
              onReplay: () {},
              onPlayAgain: () {},
              onExit: () {},
              onSaveReplay: () {},
              onSaveVideo: () {},
              onShareLink: () {},
            ),
          ),
        );
        final center = tester.getCenter(
          find.byKey(const ValueKey('winner-result-panel')),
        );
        expect(center.dx, closeTo(size.width / 2, .5));
        expect(center.dy, closeTo(size.height / 2, .5));
        expect(
          find.byKey(const ValueKey('winner-result-title')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Play again').hitTestable(), findsOneWidget);
        expect(find.text('Replay').hitTestable(), findsOneWidget);
        expect(find.text('Save replay').hitTestable(), findsOneWidget);
        await capture('results-$suffix');
        await tester.drag(
          find.byKey(const ValueKey('winner-result-scroll')),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(find.text('Play again').hitTestable(), findsOneWidget);
        await capture('results-tally-$suffix');
        await mount(SavedReplaysScreen(onOpen: (_) {}));
        expect(
          tester.getCenter(find.byType(Scaffold)).dx,
          closeTo(size.width / 2, .5),
        );
        await capture('replays-$suffix');
        final backend = _Backend();
        await mount(
          ExportVideoDialog(
            contestants: balls.take(2).toList(),
            seed: 42,
            arenaRadius: 180,
            speedMultiplier: 1,
            encoder: backend,
            saver: backend,
          ),
        );
        final dialogCenter = tester.getCenter(find.byType(AlertDialog));
        expect(dialogCenter.dx, closeTo(size.width / 2, .5));
        expect(dialogCenter.dy, closeTo(size.height / 2, .5));
        await capture('export-$suffix');
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
