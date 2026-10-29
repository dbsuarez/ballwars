import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_painter.dart';
import 'package:ballwars/features/arena_simulation/presentation/ball_face_expression.dart';
import 'package:ballwars/features/arena_simulation/presentation/hp_bar.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/ball_studio_screen.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_state.dart';
import 'package:ballwars/features/arena_simulation/domain/floating_text.dart';
import 'package:ballwars/features/arena_simulation/domain/particle_system.dart';

SimulationBall ball() => SimulationBall(
  config: const CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.cyan,
    glowColor: Colors.cyan,
  ),
  position: const Offset(48, 48),
  velocity: Offset.zero,
  radius: 28,
  lineCount: 0,
)..life = 100;

class _Canvas extends Fake implements Canvas {
  final rects = <(Rect, PaintingStyle, double)>[];
  final circles = <double>[];
  @override
  void drawRect(Rect rect, Paint paint) =>
      rects.add((rect, paint.style, paint.strokeWidth));
  @override
  void drawCircle(Offset at, double r, Paint paint) => circles.add(r);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  testWidgets(
    'the game arena reads shared appearance and updates after saving',
    (tester) async {
      final settings = ValueNotifier(
        AppSettings.defaults.copyWith(
          ballAppearance: const BallAppearance(
            hpBarSize: HpBarSize.large,
            handStyle: BallHandStyle.mittens,
          ),
        ),
      );
      final state = SimulationState(
        balls: [ball()],
        particles: ParticleSystem(),
        floatingTexts: FloatingTextManager(),
        status: MatchStatus.running,
        winnerId: null,
        arenaRadius: 110,
      );
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          child: MaterialApp(
            home: ArenaCanvas(state: state, arenaRadius: 110, rimAngle: 0),
          ),
        ),
      );
      await tester.pump();
      ArenaPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byType(ArenaCanvas),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as ArenaPainter;
      expect(painter().ballAppearance.hpBarSize, HpBarSize.large);
      expect(painter().ballAppearance.handStyle, BallHandStyle.mittens);
      settings.value = settings.value.copyWith(
        ballAppearance: const BallAppearance(handScale: 1.5),
      );
      await tester.pump();
      expect(painter().ballAppearance.handScale, 1.5);
    },
  );
  test('appearance serializes and normalizes older or malformed settings', () {
    const value = BallAppearance(
      hpBarSize: HpBarSize.large,
      handScale: 1.5,
      handStyle: BallHandStyle.mittens,
      expressiveFaces: false,
    );
    expect(
      BallAppearance.fromJson(jsonDecode(jsonEncode(value.toJson()))),
      value,
    );
    expect(BallAppearance.fromJson(null), BallAppearance.defaults);
    expect(
      BallAppearance.fromJson({
        'hand_scale': double.nan,
        'hp_bar_size': 'unknown',
      }),
      BallAppearance.defaults,
    );
    expect(BallAppearance.fromJson({'hand_scale': 100}).handScale, 2);
  });
  test(
    'small retains geometry; larger bars grow upward and have a fixed outline',
    () {
      final b = ball();
      final small = hpBarFor(b, maxLife: 150)!;
      expect(small.track.width, closeTo(b.radius * 1.6, .001));
      for (final size in HpBarSize.values) {
        final bar = hpBarFor(b, maxLife: 150, size: size)!;
        expect(bar.track.width, closeTo(small.track.width * size.scale, .001));
        expect(bar.track.bottom, closeTo(small.track.bottom, .001));
        final canvas = _Canvas();
        HpBar.paintAll(canvas, [b], maxLife: 150, size: size, outlineWidth: .5);
        expect(canvas.rects.last.$2, PaintingStyle.stroke);
        expect(canvas.rects.last.$3, .5);
      }
    },
  );
  test(
    'expressions react to status while classic mode preserves original rules',
    () {
      final b = ball()..stunnedLeft = 10;
      expect(expressionFor(b, .9), FaceExpression.dizzy);
      expect(expressionFor(b, .9, expressive: false), FaceExpression.happy);
      b
        ..stunnedLeft = 0
        ..aimLeft = 10;
      expect(expressionFor(b, .9), FaceExpression.determined);
      b
        ..aimLeft = 0
        ..overchargeLeft = 10;
      expect(expressionFor(b, .9), FaceExpression.angry);
      b.overchargeLeft = 0;
      expect(expressionFor(b, 1.2), FaceExpression.grinning);
      expect(expressionFor(b, .1), FaceExpression.sad);
      b.hurtFlashLeft = 5;
      expect(expressionFor(b, .1), FaceExpression.wince);
    },
  );
  test('all eleven code-drawn expressions are visually distinct', () async {
    final frames = <String>{};
    for (final expression in FaceExpression.values) {
      final recorder = ui.PictureRecorder();
      paintSmiley(
        Canvas(recorder),
        ball(),
        .7,
        [],
        expressionOverride: expression,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(96, 96);
      final bytes = await image.toByteData();
      frames.add(base64Encode(bytes!.buffer.asUint8List()));
      image.dispose();
      picture.dispose();
    }
    expect(frames.length, FaceExpression.values.length);
  });
  test(
    'configured hand size changes drawing rather than ball collision radius',
    () {
      final b = ball(), normal = _Canvas(), large = _Canvas();
      paintHands(normal, b);
      paintHands(large, b, appearance: const BallAppearance(handScale: 1.5));
      expect(large.circles.first, closeTo(normal.circles.first * 1.5, .001));
      expect(b.radius, 28);
    },
  );
  testWidgets(
    'phone preview keeps drafts across tabs and save errors retain edits for retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var attempts = 0;
      AppSettings? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: BallStudioScreen(
            initial: AppSettings.defaults,
            onSave: (value) async {
              if (++attempts == 1) throw StateError('Offline');
              saved = value;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('ball-studio-preview'))).width,
        greaterThan(300),
      );
      await tester.tap(find.widgetWithText(Tab, 'Face & hands'));
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(find.byKey(const ValueKey('studio-hand-scale')))
          .onChanged!(1.5);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'HP bar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<HpBarSize>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Large').last);
      await tester.pumpAndSettle();
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const ValueKey('ball-studio-preview')),
                  )
                  .painter!
              as ArenaPainter;
      expect(painter.ballAppearance.handScale, 1.5);
      expect(painter.ballAppearance.hpBarSize, HpBarSize.large);
      await tester.tap(find.byKey(const ValueKey('save-ball-studio')));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Save failed: Offline'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-ball-studio')));
      await tester.pumpAndSettle();
      expect(saved!.ballAppearance.handScale, 1.5);
      expect(saved!.ballAppearance.hpBarSize, HpBarSize.large);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
