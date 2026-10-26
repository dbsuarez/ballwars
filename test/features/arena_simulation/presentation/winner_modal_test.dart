import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/winner_modal.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  const winner = CustomBall(
    id: 'a',
    name: 'Alpha',
    primaryColor: Colors.teal,
    glowColor: Colors.cyan,
  );

  test('series ranking uses wins, then losses, then remaining HP', () {
    const beta = CustomBall(
      id: 'b',
      name: 'Beta',
      primaryColor: Colors.red,
      glowColor: Colors.red,
    );
    const gamma = CustomBall(
      id: 'c',
      name: 'Gamma',
      primaryColor: Colors.blue,
      glowColor: Colors.blue,
    );
    const delta = CustomBall(
      id: 'd',
      name: 'Delta',
      primaryColor: Colors.green,
      glowColor: Colors.green,
    );
    final ranked = rankSeriesStandings([
      (ball: winner, wins: 3, losses: 2, hp: 90),
      (ball: beta, wins: 4, losses: 3, hp: 100),
      (ball: gamma, wins: 3, losses: 1, hp: 20),
      (ball: delta, wins: 3, losses: 1, hp: 70),
    ]);

    expect(ranked.map((entry) => entry.ball.id), ['b', 'd', 'c', 'a']);
  });

  Future<void> pump(
    WidgetTester tester, {
    void Function(bool, bool)? onSlowAnswer,
    String? winningMove,
  }) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Scaffold(
          body: WinnerModal(
            winner: winner,
            winningMove: winningMove,
            onReplay: () {},
            onPlayAgain: () {},
            onExit: () {},
            onSlowAnswer: onSlowAnswer,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('shows the weapon used for the winning move', (tester) async {
    await pump(tester, winningMove: 'Pistol');
    expect(find.text('Winning move: Pistol'), findsOneWidget);
  });

  testWidgets('can replay a finishing move without replaying the match', (
    tester,
  ) async {
    var replayed = false;
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Scaffold(
          body: WinnerModal(
            winner: winner,
            winningMove: 'Hook',
            onReplay: () {},
            onReplayFinisher: () => replayed = true,
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('replay-finisher')));
    expect(replayed, isTrue);
  });

  testWidgets(
    'asks whether to turn effects off; the answer and "don\'t ask again" are passed on',
    (tester) async {
      (bool, bool)? answer;
      await pump(
        tester,
        onSlowAnswer: (off, dontAsk) => answer = (off, dontAsk),
      );
      expect(find.text('Game running slow?'), findsOneWidget);

      await tester.tap(find.text("Don't ask again"));
      await tester.pump();
      await tester.tap(find.text('Turn off'));
      await tester.pump();
      expect(answer, (true, true));
      expect(find.text('Game running slow?'), findsNothing);
    },
  );

  testWidgets('No keeps effects on', (tester) async {
    (bool, bool)? answer;
    await pump(tester, onSlowAnswer: (off, dontAsk) => answer = (off, dontAsk));
    await tester.tap(find.text('No'));
    await tester.pump();
    expect(answer, (false, false));
  });

  testWidgets('no question when there is nothing to ask', (tester) async {
    await pump(tester);
    expect(find.text('Game running slow?'), findsNothing);
  });

  testWidgets(
    'the confetti falls for a while, fades and stops, so the card stops redrawing',
    (tester) async {
      await pump(tester);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(WinnerModal.confettiDuration);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    },
  );
  testWidgets('Mayhem winner screen ranks the complete knockout tally', (
    tester,
  ) async {
    const other = CustomBall(
      id: 'b',
      name: 'Beta',
      primaryColor: Colors.red,
      glowColor: Colors.red,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Scaffold(
          body: WinnerModal(
            winner: winner,
            mayhemTally: const [(other, 4, 25.0), (winner, 4, 72.5)],
            showEffects: false,
            onReplay: () {},
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('MAYHEM TALLY'), findsOneWidget);
    expect(find.text('4 KOs'), findsNWidgets(2));
    expect(find.text('72.5 HP'), findsOneWidget);
    expect(find.text('25.0 HP'), findsOneWidget);
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('mayhem-result-a')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('mayhem-result-b')),
    );
    expect(first.dy, lessThan(second.dy));
  });
}
