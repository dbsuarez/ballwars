import 'package:ballwars/features/lobby/presentation/lobby_hero.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/presentation/power_up_test_screen.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/core/utils/ball_image_loader.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';

/// Offline runtime captures, not production/account screenshots.
/// flutter test test/visual/capture_player_ui.dart
class _Groups extends Fake implements CustomGroupRepository {}

class _Auth extends Fake implements AdminAuth {
  @override
  Future<bool> isAdmin() async => true;
  @override
  Future<bool?> adminStatus() async => true;
}

void main() {
  testWidgets('capture actual player widgets with offline fixtures', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final font in [
      ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
      ('JetBrains Mono', 'assets/fonts/JetBrainsMono-Medium.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
    await tester.runAsync(() => PowerUpSprites.load());
    final previousStore = OfflineStore.instance,
        previousFetch = BallImageLoader.fetch;
    OfflineStore.instance = MemoryOfflineStore();
    BallImageLoader.clearCache();
    addTearDown(() {
      OfflineStore.instance = previousStore;
      BallImageLoader.fetch = previousFetch;
      BallImageLoader.clearCache();
    });
    const samples = [
      ('crimson', 'Crimson', Color(0xFFFF5C64)),
      ('volt', 'Volt', Color(0xFF54DFFF)),
      ('phantom', 'Phantom', Color(0xFFAE70FF)),
      ('blaze', 'Blaze', Color(0xFFFFD458)),
    ];
    final pngs = <String, Uint8List>{};
    await tester.runAsync(() async {
      for (final data in samples) {
        final ball = SimulationBall(
          config: CustomBall(
            id: data.$1,
            name: data.$2,
            primaryColor: data.$3,
            glowColor: data.$3,
          ),
          position: const Offset(48, 48),
          velocity: Offset.zero,
          radius: 45,
          lineCount: 0,
        )..life = 100;
        final recorder = ui.PictureRecorder();
        paintSmiley(Canvas(recorder), ball, 1, [
          ball,
        ], expressionOverride: FaceExpression.determined);
        final picture = recorder.endRecording(),
            image = await picture.toImage(96, 96);
        pngs['/${data.$1}.png'] = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        image.dispose();
        picture.dispose();
      }
    });
    BallImageLoader.fetch = (url) async => pngs[url.path]!;
    final catalog = jsonEncode({
      'version': 1,
      'groups': [
        {
          'id': 'sample',
          'name': 'Sample fighters',
          'style': 'flag',
          'balls': [
            for (final b in samples)
              {
                'id': b.$1,
                'name': b.$2,
                'image': '${b.$1}.png',
                'color': '#${b.$3.toARGB32().toRadixString(16).substring(2)}',
              },
          ],
        },
      ],
    });
    final packs = BallPackRepository(
      baseUri: Uri.parse('https://fixture.invalid/'),
      fetch: (_) async => catalog,
    );
    final loaded = await packs.load();
    await tester.runAsync(() async {
      for (final b in loaded.single.balls) {
        await BallImageLoader.load(b);
      }
    });
    final key = GlobalKey();
    Widget setup() => RepaintBoundary(
      key: key,
      child: AppSettingsScope(
        settings: ValueNotifier(AppSettings.defaults),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (_, child) => AppFrame(child: child!),
          theme: AppTheme.build(AppPalettes.midnight),
          home: MatchSetupScreen(
            initialMode: MatchMode.arsenal,
            packRepository: packs,
            onStartBattle: (_) {},
          ),
        ),
      ),
    );
    Future<void> capture(String name) async {
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('build/game-ui-screenshots').create(recursive: true);
        await File(
          'build/game-ui-screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(440, 900),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: BallWarsApp(customGroups: _Groups()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          tester
              .widget<Image>(
                find
                    .descendant(
                      of: find.byType(LobbyHero),
                      matching: find.byType(Image),
                    )
                    .first,
              )
              .image,
          tester.element(find.byType(Scaffold).first),
        ),
      );
      await tester.pumpAndSettle();
      await capture('home-${size.width.toInt()}x${size.height.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(setup());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('start-battle')));
      await capture(
        'setup-disabled-${size.width.toInt()}x${size.height.toInt()}',
      );
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('start-battle')));
      await capture('setup-${size.width.toInt()}x${size.height.toInt()}');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    Widget powerTest() => RepaintBoundary(
      key: key,
      child: AppSettingsScope(
        settings: ValueNotifier(AppSettings.defaults),
        adminAuth: _Auth(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(AppPalettes.midnight),
          builder: (_, child) => AppFrame(child: child!),
          home: const PowerUpTestScreen(),
        ),
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(powerTest());
    await tester.pumpAndSettle();
    await capture('powerup-390x844');
    await tester.tap(find.byKey(const ValueKey('toggle-test-rail-0')));
    await tester.pumpAndSettle();
    await capture('powerup-collapsed-390x844');
    await tester.tap(find.byKey(const ValueKey('toggle-test-rail-0')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 740);
    await tester.pumpAndSettle();
    await capture('powerup-320x740');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
