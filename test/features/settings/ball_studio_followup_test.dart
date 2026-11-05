import 'package:ballwars/core/utils/ball_image_loader.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/settings/data/ball_appearance_preset_store.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/ball_studio_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

class FailingStore extends MemoryOfflineStore {
  bool fail = false;
  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (fail) throw StateError('Storage full');
    return super.write(key, bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  const appearance = BallAppearance(
    mouthScale: 1.3,
    pupilFollow: .4,
    blinkInterval: 3,
    blinkDuration: .2,
  );
  const preset = BallAppearancePreset(
    name: 'Soft',
    appearance: appearance,
    glowEnabled: false,
    glowWidth: 7,
  );
  ArenaPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.byKey(const ValueKey('ball-studio-preview')),
              )
              .painter!
          as ArenaPainter;
  Future<void> tab(WidgetTester tester, String label) async {
    final target = find.widgetWithText(Tab, label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  test('all new face parameters round-trip, clamp and default safely', () {
    expect(
      BallAppearance.fromJson(jsonDecode(jsonEncode(appearance.toJson()))),
      appearance,
    );
    final bad = BallAppearance(
      mouthScale: double.nan,
      pupilFollow: 99,
      blinkInterval: double.infinity,
      blinkDuration: -10,
    ).validated();
    expect(bad.mouthScale, 1);
    expect(bad.pupilFollow, 2);
    expect(bad.blinkInterval, 0);
    expect(bad.blinkDuration, .06);
    expect(BallAppearance.fromJson({}), BallAppearance.defaults);
    expect(appearance == appearance.copyWith(mouthScale: 1), isFalse);
  });
  test(
    'presets confirm writes, preserve old data on failure and reject unreadable libraries',
    () async {
      final memory = FailingStore();
      OfflineStore.instance = memory;
      final store = BallAppearancePresetStore();
      await store.save([preset]);
      memory.fail = true;
      await expectLater(store.save([]), throwsStateError);
      expect((await store.load()).single.name, 'Soft');
      memory.fail = false;
      await expectLater(store.save([preset, preset]), throwsStateError);
      await DevicePrefs.writeRequired(BallAppearancePresetStore.key, 'corrupt');
      await expectLater(store.load(), throwsFormatException);
    },
  );
  test(
    'blink uses a deterministic 60Hz cosmetic clock without changing the ball',
    () {
      final config = appearance.copyWith(blinkInterval: 1);
      final frames = [
        for (var i = 1; i <= 60; i++) isFaceBlinking('sample', i, config),
      ];
      expect(frames.where((v) => v).length, 12);
      expect([
        for (var i = 1; i <= 60; i++) isFaceBlinking('sample', i, config),
      ], frames);
      expect(isFaceBlinking('sample', 0, config), false);
      expect(isFaceBlinking('sample', 60, BallAppearance.defaults), false);
    },
  );
  test(
    'mouth size and tracking alter real face pixels, blinking closes eyes',
    () async {
      final ball = SimulationBall(
        config: const CustomBall(
          id: 'sample',
          name: 'Sample',
          primaryColor: Colors.cyan,
          glowColor: Colors.cyan,
        ),
        position: const Offset(48, 48),
        velocity: Offset.zero,
        radius: 35,
        lineCount: 0,
      );
      final opponent = SimulationBall(
        config: const CustomBall(
          id: 'other',
          name: 'Other',
          primaryColor: Colors.red,
          glowColor: Colors.red,
        ),
        position: const Offset(150, 48),
        velocity: Offset.zero,
        radius: 35,
        lineCount: 0,
      );
      Future<String> pixels(BallAppearance a, {int step = 0}) async {
        final recorder = ui.PictureRecorder();
        paintSmiley(
          Canvas(recorder),
          ball,
          .7,
          [ball, opponent],
          appearance: a,
          animationStep: step,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(96, 96);
        final data = await image.toByteData();
        final result = base64Encode(data!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        return result;
      }

      final baseline = await pixels(BallAppearance.defaults);
      expect(
        await pixels(const BallAppearance(mouthScale: 1.5)),
        isNot(baseline),
      );
      expect(
        await pixels(const BallAppearance(pupilFollow: 0)),
        isNot(baseline),
      );
      final step = List.generate(60, (i) => i + 1).firstWhere(
        (i) =>
            isFaceBlinking('sample', i, appearance.copyWith(blinkInterval: 1)),
      );
      expect(
        await pixels(appearance.copyWith(blinkInterval: 1), step: step),
        isNot(await pixels(appearance.copyWith(blinkInterval: 1))),
      );
      expect(ball.position, const Offset(48, 48));
      expect(ball.radius, 35);
    },
  );
  testWidgets(
    'saved-ball picture, both looks, phone and six-ball previews use the real painter',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final png = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.purple, BlendMode.src);
        final pic = recorder.endRecording();
        final image = await pic.toImage(8, 8);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        pic.dispose();
        return png;
      });
      final saved = CustomBall(
        id: 'saved',
        name: 'Saved portrait',
        primaryColor: Colors.orange,
        glowColor: Colors.orange,
        imageBytes: png!.buffer.asUint8List(),
      );
      expect(
        await tester.runAsync(() => BallImageLoader.load(saved)),
        isNotNull,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            previewBalls: [saved],
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Preview');
      await tester.tap(find.byKey(const ValueKey('studio-ball-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved portrait').last);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      expect(painter(tester).state.balls.single.config.id, 'saved');
      expect(painter(tester).state.balls.single.cachedUiImage, isNotNull);
      await tester.tap(
        find.byKey(const ValueKey('studio-look-BallLook.faces')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Both').last);
      await tester.pumpAndSettle();
      expect(painter(tester).look, BallLook.both);
      await tester.tap(find.byKey(const ValueKey('studio-scene-Single')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Six balls').last);
      await tester.pumpAndSettle();
      expect(painter(tester).state.balls.length, 6);
      expect(
        painter(tester).state.balls.map((b) => b.config.id).toSet().length,
        6,
      );
      await tester.tap(find.byKey(const ValueKey('studio-scene-Six balls')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Phone').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('studio-phone-frame')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        MaterialApp(
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            previewBalls: [saved],
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(painter(tester).look, BallLook.both);
      expect(painter(tester).state.balls.single.config.id, 'saved');
      expect(find.byKey(const ValueKey('studio-phone-frame')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'preset save and apply keep shared settings untouched until Save',
    (tester) async {
      AppSettings? shared;
      await tester.pumpWidget(
        MaterialApp(
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            onSave: (s) async {
              shared = s;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Presets');
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('studio-preset-name')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(
        find.byKey(const ValueKey('studio-preset-name')),
        'My look',
      );
      await tester.ensureVisible(find.text('Save draft as preset'));
      await tester.tap(find.text('Save draft as preset'));
      await tester.pumpAndSettle();
      expect((await BallAppearancePresetStore().load()).single.name, 'My look');
      expect(shared, isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await BallAppearancePresetStore().save([preset]);
      await tester.pumpWidget(
        MaterialApp(
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            onSave: (s) async {
              shared = s;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Presets');
      await tester.tap(find.byKey(const ValueKey('studio-preset-null')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soft').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to draft'));
      await tester.pump(); // blink starts; avoid settling an animated preview
      expect(painter(tester).ballAppearance, appearance);
      expect(painter(tester).showBallGlow, false);
      expect(shared, isNull);
      await tester.tap(find.byKey(const ValueKey('save-ball-studio')));
      await tester.pump();
      expect(shared!.ballAppearance, appearance);
      expect(shared!.ballGlowWidth, 7);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed preset writes are visible, keep the draft and retry successfully',
    (tester) async {
      final storage = FailingStore();
      OfflineStore.instance = storage;
      await tester.pumpWidget(
        MaterialApp(
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tab(tester, 'Presets');
      final name = find.byKey(const ValueKey('studio-preset-name'));
      await tester.scrollUntilVisible(
        name,
        150,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(name, 'Keep me');
      await tester.ensureVisible(find.text('Save draft as preset'));
      storage.fail = true;
      await tester.tap(find.text('Save draft as preset'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Preset save failed:'), findsOneWidget);
      expect(tester.widget<TextField>(name).controller!.text, 'Keep me');
      expect(await BallAppearancePresetStore().load(), isEmpty);
      storage.fail = false;
      await tester.tap(find.text('Save draft as preset'));
      await tester.pumpAndSettle();
      expect((await BallAppearancePresetStore().load()).single.name, 'Keep me');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
