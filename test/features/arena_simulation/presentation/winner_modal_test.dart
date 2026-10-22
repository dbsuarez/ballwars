import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/winner_modal.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

void main() {
  const winner = CustomBall(id: 'a', name: 'Alpha', primaryColor: Colors.teal, glowColor: Colors.cyan);

  Future<void> pump(WidgetTester tester, {void Function(bool, bool)? onSlowAnswer}) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Scaffold(
          body: WinnerModal(winner: winner, onReplay: () {}, onExit: () {}, onSlowAnswer: onSlowAnswer),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('asks whether to turn effects off; the answer and "don\'t ask again" are passed on', (tester) async {
    (bool, bool)? answer;
    await pump(tester, onSlowAnswer: (off, dontAsk) => answer = (off, dontAsk));
    expect(find.text('Game running slow?'), findsOneWidget);

    await tester.tap(find.text("Don't ask again"));
    await tester.pump();
    await tester.tap(find.text('Turn off'));
    await tester.pump();
    expect(answer, (true, true));
    expect(find.text('Game running slow?'), findsNothing);
  });

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
}
