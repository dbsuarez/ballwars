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

    expect(find.text('A: 50%'), findsOneWidget);
    expect(find.text('B: 50%'), findsOneWidget);

    // Stop the ticker cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
