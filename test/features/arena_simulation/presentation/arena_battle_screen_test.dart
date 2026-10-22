import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  testWidgets('renders the arena and scoreboard for a fresh match', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config),
    ));
    await tester.pump();

    // Each ball starts holding half the rim.
    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 50%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('timer counts match time and RETRY resets it', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config, seed: 3),
    ));
    await tester.pump();
    expect(find.text('0.0s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0.0s'), findsNothing);

    await tester.tap(find.text('RETRY'));
    await tester.pump();
    expect(find.text('0.0s'), findsOneWidget);
    expect(find.text('A: 50%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('both RETRY buttons work once the winner card is showing', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    Future<void> playUntilWinnerCard() async {
      for (var i = 0; i < 600 && find.text('EXIT').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('EXIT'), findsOneWidget);
      // Let the card's entry animation finish.
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config, seed: 3),
    ));
    await tester.pump();

    // The RETRY under the scoreboard (first in the tree).
    await playUntilWinnerCard();
    expect(find.text('RETRY').hitTestable(), findsNWidgets(2));
    await tester.tap(find.text('RETRY').first);
    await tester.pump();
    expect(find.text('EXIT'), findsNothing);
    expect(find.text('0.0s'), findsOneWidget);

    // The RETRY on the winner card.
    await playUntilWinnerCard();
    await tester.tap(find.text('RETRY').last);
    await tester.pump();
    expect(find.text('EXIT'), findsNothing);
    expect(find.text('0.0s'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pause button toggles between pause and play icons', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();

    expect(find.byIcon(Icons.pause), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('restart button resets the match back to the starting half-rim split', (tester) async {
    final config = MatchConfig(
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: ArenaBattleScreen(config: config, seed: 3),
    ));
    await tester.pump();
    // Let enough simulated time pass for bounces/territory changes to happen.
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump();

    // Restarting must bring the match back to each ball holding half the rim.
    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 50%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first-to-2 series: round result, NEXT ROUND, round counter', (tester) async {
    final config = MatchConfig(
      winsNeeded: 2,
      contestants: const [
        CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.pink),
        CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.cyan),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: ArenaBattleScreen(config: config, seed: 3)));
    await tester.pump();
    expect(find.text('ROUND 1'), findsOneWidget);

    for (var i = 0; i < 600 && find.text('EXIT').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('WINS ROUND 1!'), findsOneWidget);
    expect(find.textContaining('A  '), findsOneWidget); // score line, e.g. "A  1   ·   B  0"

    await tester.tap(find.text('NEXT ROUND'));
    await tester.pump();
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('EXIT'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

