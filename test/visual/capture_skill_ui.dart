// Explicit runtime capture: flutter test test/visual/capture_skill_ui.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/ball_studio_screen.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';

void main() {
  testWidgets('Phase C real screens fit portrait and short landscape', (
    tester,
  ) async {
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
        await Directory('build/phase-c-screenshots').create(recursive: true);
        await File(
          'build/phase-c-screenshots/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> mount(Widget child) async {
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
      await tester.pumpAndSettle();
    }

    for (final size in [
      const Size(360, 800),
      const Size(800, 360),
      const Size(440, 900),
    ]) {
      tester.view.physicalSize = size;
      final suffix = '${size.width.toInt()}x${size.height.toInt()}';
      await mount(
        const SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
        ),
      );
      await capture('library-$suffix');
      // Use the first visible real skill, without depending on display order.
      final skillEntry = find
          .byWidgetPredicate(
            (w) =>
                w is Text &&
                w.key is ValueKey<String> &&
                (w.key as ValueKey<String>).value.startsWith('skill-name-'),
          )
          .first;
      expect(skillEntry, findsOneWidget);
      await tester.ensureVisible(skillEntry);
      await tester.pumpAndSettle();
      await tester.tap(skillEntry);
      await tester.pumpAndSettle();
      await capture('editor-$suffix');
      expect(
        find.byKey(const ValueKey('save-skill')).hitTestable(),
        findsOneWidget,
      );
      await mount(
        BallStudioScreen(initial: AppSettings.defaults, onSave: (_) async {}),
      );
      await capture('studio-$suffix');
      await mount(
        SkillDemoDialog(
          skill: SkillLibrary.defaults.all(PowerUpConfig.defaults).first,
          library: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
        ),
      );
      await capture('demo-$suffix');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
