import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/core/theme/game_ui.dart';
import 'package:ballwars/core/widgets/animated_empty_state.dart';
import 'package:ballwars/features/lobby/presentation/lobby_hero.dart';
import 'package:ballwars/features/arena_simulation/presentation/winner_modal.dart';
import 'package:ballwars/features/arena_simulation/presentation/confetti_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

class _CountPaints extends CustomPainter {
  _CountPaints(this.delegate);
  final CustomPainter delegate;
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    delegate.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _CountPaints oldDelegate) => false;
}

void main() {
  testWidgets(
    'menu entrance finishes and reduced motion is immediate without losing text focus',
    (tester) async {
      final reduced = ValueNotifier(false);
      final controller = TextEditingController();
      addTearDown(reduced.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            builder: (context, value, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: value),
              child: Scaffold(
                body: GameEntrance(child: TextField(controller: controller)),
              ),
            ),
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(GameEntrance),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(opacity).opacity, 0);
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.widget<Opacity>(opacity).opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.enterText(find.byType(TextField), 'Unsaved draft');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
      reduced.value = true;
      await tester.pump();
      expect(controller.text, 'Unsaved draft');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).focusNode,
        same(editable.focusNode),
      );
      expect(editable.focusNode.hasFocus, isTrue);
      expect(tester.widget<Opacity>(opacity).opacity, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('reduced motion skips empty-state scaling and winner confetti', (
    tester,
  ) async {
    Widget app(Widget child) => MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(800, 600),
          disableAnimations: true,
        ),
        child: Scaffold(body: child),
      ),
    );
    await tester.pumpWidget(
      app(const AnimatedEmptyState(message: 'No entries')),
    );
    expect(
      tester
          .widget<Transform>(find.byType(Transform).last)
          .transform
          .getMaxScaleOnAxis(),
      1,
    );
    await tester.pumpWidget(
      app(
        WinnerModal(
          winner: const CustomBall(
            id: 'a',
            name: 'Alpha',
            primaryColor: Colors.red,
            glowColor: Colors.red,
          ),
          onReplay: () {},
          onPlayAgain: () {},
          onExit: () {},
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('winner-result-title')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is ConfettiPainter,
      ),
      findsNothing,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected mode remains keyboard operable and motion can be disabled',
    (tester) async {
      var activated = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  height: 120,
                  child: GameModeTile(
                    title: 'Mayhem',
                    subtitle: 'Timed score',
                    icon: Icons.flash_on,
                    accent: Colors.cyan,
                    selected: true,
                    onTap: () => activated++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(activated, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('static chrome stays cached across forty changing child frames', (
    tester,
  ) async {
    final color = ValueNotifier(Colors.red);
    addTearDown(color.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: GameTheme(
          child: GameBackdrop(
            child: ValueListenableBuilder<Color>(
              valueListenable: color,
              builder: (_, value, _) => Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: ColoredBox(color: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('game-backdrop-artwork')),
    );
    boundary.debugResetMetrics();
    for (var i = 0; i < 40; i++) {
      color.value = i.isEven ? Colors.blue : Colors.red;
      await tester.pump();
    }
    expect(boundary.debugSymmetricPaintCount, 0);
    expect(boundary.debugAsymmetricPaintCount, 40);
    final painter = tester
        .widget<CustomPaint>(find.byType(CustomPaint).last)
        .painter!;
    final baseline = _CountPaints(painter);
    // Previous composition: static paint and changing child share one layer.
    await tester.pumpWidget(
      MaterialApp(
        home: CustomPaint(
          painter: baseline,
          child: ValueListenableBuilder<Color>(
            valueListenable: color,
            builder: (_, value, _) => Center(
              child: SizedBox(
                width: 60,
                height: 60,
                child: ColoredBox(color: value),
              ),
            ),
          ),
        ),
      ),
    );
    final initialPaints = baseline.paints;
    for (var i = 0; i < 40; i++) {
      color.value = i.isEven ? Colors.blue : Colors.red;
      await tester.pump();
    }
    expect(baseline.paints - initialPaints, 40);
    debugPrint(
      'PHASE_E_PAINT frames=40 baseline_static_repaints=${baseline.paints - initialPaints} isolated_static_repaints=0 cached_reuses=40',
    );
  });

  testWidgets(
    'home artwork decode width follows viewport pixels and stays capped',
    (tester) async {
      for (final ratio in [1.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                devicePixelRatio: ratio,
              ),
              child: const Scaffold(
                body: SizedBox(width: 360, height: 220, child: LobbyHero()),
              ),
            ),
          ),
        );
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byType(LobbyHero),
            matching: find.byType(Image),
          ),
        );
        expect((image.image as ResizeImage).width, ratio == 1 ? 360 : 940);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
