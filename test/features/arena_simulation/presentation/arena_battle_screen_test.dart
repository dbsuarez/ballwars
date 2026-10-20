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

    // Matches start fully neutral -- no territory claimed yet.
    expect(find.text('A: 0%'), findsOneWidget);
    expect(find.text('B: 0%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
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

  testWidgets('restart button resets the match back to neutral territory', (tester) async {
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

    // Restarting must bring the match back to its fully neutral starting state.
    expect(find.text('A: 0%'), findsOneWidget);
    expect(find.text('B: 0%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
