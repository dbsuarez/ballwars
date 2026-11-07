// Runtime rendering only; no external account or production writes.
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
import 'package:ballwars/features/custom_groups/data/custom_group_repository.dart';
import 'package:ballwars/features/custom_groups/domain/custom_group.dart';
import 'package:ballwars/features/custom_groups/presentation/my_groups_screen.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/settings_screen.dart';
import 'package:ballwars/features/settings/presentation/power_up_test_screen.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'Crimson',
    primaryColor: Colors.redAccent,
    glowColor: Colors.redAccent,
  ),
  CustomBall(
    id: 'b',
    name: 'Volt',
    primaryColor: Colors.cyan,
    glowColor: Colors.cyan,
  ),
];

class _Groups extends Fake implements CustomGroupRepository {
  @override
  String? get userId => 'fixture';
  @override
  Future<List<CustomGroup>> myGroups() async => [
    const CustomGroup(
      id: 'crew',
      name: 'Neon Crew',
      isPublic: false,
      balls: _balls,
    ),
  ];
  @override
  Future<List<CustomGroup>> savedGroups() async => [];
  @override
  Future<Set<String>> submittedGroupIds() async => {};
}

class _Auth extends Fake implements AdminAuth {
  @override
  Future<bool> isAdmin() async => true;
  @override
  Future<bool?> adminStatus() async => true;
  @override
  String? get email => 'fixture@example.com';
}

class _Settings extends Fake implements AppSettingsRepository {
  @override
  Future<AppSettings> load() async => AppSettings.defaults;
  @override
  Future<void> save(AppSettings settings) async {}
}

void main() {
  testWidgets('Phase E real screens fit portrait, landscape and keyboard', (
    tester,
  ) async {
    final previous = OfflineStore.instance;
    OfflineStore.instance = MemoryOfflineStore();
    addTearDown(() => OfflineStore.instance = previous);
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
        await Directory('build/phase-e-screenshots').create(recursive: true);
        await File(
          'build/phase-e-screenshots/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> mount(
      Widget child, {
      double textScale = 1,
      bool reducedMotion = false,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: AppSettingsScope(
            settings: ValueNotifier(AppSettings.defaults),
            repository: _Settings(),
            adminAuth: _Auth(),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(AppPalettes.midnight),
              builder: (_, child) => AppFrame(
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(textScale),
                      disableAnimations: reducedMotion,
                    ),
                    child: child!,
                  ),
                ),
              ),
              home: child,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(440, 900),
    ]) {
      tester.view.physicalSize = size;
      final suffix = '${size.width.toInt()}x${size.height.toInt()}';
      await mount(MyGroupsScreen(repository: _Groups()));
      await capture('groups-$suffix');
      await tester.tap(find.text('Crimson'));
      await tester.pumpAndSettle();
      await capture('ball-editor-$suffix');
      final name = find.byType(TextField).last;
      await tester.enterText(name, 'Crimson draft');
      tester.view.viewInsets = const FakeViewPadding(bottom: 120);
      await tester.pumpAndSettle();
      await tester.ensureVisible(name);
      await tester.pumpAndSettle();
      await capture('ball-editor-keyboard-$suffix');
      tester.view.viewInsets = const FakeViewPadding();
      await mount(const SettingsScreen());
      await capture('settings-$suffix');
      await mount(const PowerUpTestScreen());
      await capture('powerup-$suffix');
    }
    tester.view.physicalSize = const Size(360, 800);
    await mount(
      MyGroupsScreen(repository: _Groups()),
      textScale: 1.4,
      reducedMotion: true,
    );
    await capture('groups-large-text-reduced-360x800');
    await mount(const SettingsScreen(), textScale: 1.4, reducedMotion: true);
    await capture('settings-large-text-reduced-360x800');
    final audioTab = find.widgetWithText(Tab, 'Audio');
    await tester.ensureVisible(audioTab);
    await tester.pumpAndSettle();
    await tester.tap(audioTab);
    await tester.pumpAndSettle();
    await capture('audio-large-text-reduced-360x800');
    await mount(const PowerUpTestScreen(), textScale: 1.4, reducedMotion: true);
    await capture('powerup-large-text-reduced-360x800');
    await tester.pumpWidget(const SizedBox());
  });
}
