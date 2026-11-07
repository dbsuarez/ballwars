import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/ui_skin.dart';
import 'package:ballwars/core/theme/ui_skin_scope.dart';
import 'package:ballwars/core/theme/garage_theme.dart';
import 'package:ballwars/core/theme/game_ui.dart';
import 'package:ballwars/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ballwars/app.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/features/lobby/presentation/game_ui_gallery.dart';

class _BrokenStore extends MemoryOfflineStore {
  bool broken = true;
  @override
  Future<void> write(String key, dynamic bytes) async {
    if (broken) throw StateError('Full');
    await super.write(key, bytes);
  }
}

class _DelayedReadStore extends MemoryOfflineStore {
  final firstRead = Completer<Uint8List?>();
  bool delayed = false;
  @override
  Future<Uint8List?> read(String key) {
    if (!delayed) {
      delayed = true;
      return firstRead.future;
    }
    return super.read(key);
  }
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('Inter', 'assets/fonts/Inter-Variable.ttf'),
      ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  test('unknown skin falls back to Classic', () {
    expect(UiSkin.fromId('removed-skin'), UiSkin.classic);
  });
  testWidgets(
    'app-wide switch retains Settings route and updates Home on return',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const BallWarsApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(SettingsScreen));
        for (final skin in UiSkin.values) {
          await precacheImage(
            ResizeImage(
              AssetImage('assets/ui/skins/${skin.id}/preview.png'),
              width: 156,
            ),
            context,
          );
        }
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Battle Garage'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(Scaffold).last),
        ).colorScheme.primary,
        GarageTheme.gold,
      );
      if (const bool.fromEnvironment('SKIN_SCREENSHOTS')) {
        await _capture(tester, 'skin-selector');
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Play'),
      );
      expect(button.style!.foregroundColor!.resolve({}), GarageTheme.ink);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('late startup read cannot overwrite a confirmed selection', () async {
    final store = _DelayedReadStore();
    OfflineStore.instance = store;
    final controller = UiSkinController();
    final loading = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.select(UiSkin.garage), isTrue);
    store.firstRead.complete(null);
    await loading;
    expect(controller.value, UiSkin.garage);
    controller.dispose();
  });
  test('choice persists across controllers and stays device-local', () async {
    final a = UiSkinController();
    expect(a.value, UiSkin.classic);
    expect(await a.select(UiSkin.garage), isTrue);
    final b = UiSkinController();
    await b.load();
    expect(b.value, UiSkin.garage);
    OfflineStore.instance = MemoryOfflineStore();
    await b.load();
    expect(b.value, UiSkin.classic);
    a.dispose();
    b.dispose();
  });
  test('failed save is visible, retains active skin, and can retry', () async {
    final store = _BrokenStore();
    OfflineStore.instance = store;
    final controller = UiSkinController();
    expect(await controller.select(UiSkin.garage), isFalse);
    expect(controller.value, UiSkin.classic);
    expect(controller.error, contains('Could not save'));
    store.broken = false;
    expect(await controller.select(UiSkin.garage), isTrue);
    expect(controller.error, isNull);
    controller.dispose();
  });
  testWidgets('public appearance selector switches skin without admin access', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = UiSkinController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      UiSkinHost(
        controller: controller,
        load: false,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('Classic Arcade'), findsOneWidget);
    await tester.tap(find.text('Battle Garage'));
    await tester.pumpAndSettle();
    expect(controller.value, UiSkin.garage);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).colorScheme.primary,
      GarageTheme.gold,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('garage primary retains native action and contrasting icon', (
    tester,
  ) async {
    final controller = UiSkinController(initial: UiSkin.garage);
    addTearDown(controller.dispose);
    var count = 0;
    await tester.pumpWidget(
      UiSkinHost(
        controller: controller,
        load: false,
        child: MaterialApp(
          home: GameWorkbench(
            builder: (_) => Scaffold(
              body: GameActionButton(label: 'Play', onPressed: () => count++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    expect(count, 1);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.style!.foregroundColor!.resolve({}), GarageTheme.ink);
    expect(tester.takeException(), isNull);
  });
  for (final skin in UiSkin.values) {
    testWidgets('${skin.label} lobby and narrow workbench remain usable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await UiSkinController().select(skin);
      await tester.pumpWidget(const BallWarsApp());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lobby-play')), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('SKIN_SCREENSHOTS')) {
        await _capture(tester, '${skin.id}-home');
      }
      final controller = UiSkinController(initial: skin);
      addTearDown(controller.dispose);
      for (final size in [const Size(320, 740), const Size(800, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          UiSkinHost(
            controller: controller,
            load: false,
            child: MaterialApp(
              theme: AppTheme.build(AppPalettes.midnight),
              builder: (_, child) => AppFrame(child: child!),
              home: const GameUiGallery(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byType(TextField),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField), 'Keep my draft');
        await tester.pumpAndSettle();
        await controller.select(
          skin == UiSkin.classic ? UiSkin.garage : UiSkin.classic,
        );
        await tester.pumpAndSettle();
        expect(find.text('Keep my draft'), findsOneWidget);
        await controller.select(skin);
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('SKIN_SCREENSHOTS')) {
          await _capture(tester, '${skin.id}-workbench-${size.width.toInt()}');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/ux/skins/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
