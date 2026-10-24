import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/arena_simulation/presentation/scoreboard_overlay.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

SimulationBall _ball(String id, int lines) => SimulationBall(
      config: CustomBall(id: id, name: id.toUpperCase(), primaryColor: Colors.red, glowColor: Colors.pink),
      position: Offset.zero,
      velocity: Offset.zero,
      radius: 20,
      lineCount: lines,
    );

void main() {
  testWidgets('shows each ball with its lines, and round wins in a series', (tester) async {
    final balls = [_ball('a', 90), _ball('b', 45)..isEliminated = true];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: balls))));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('90 lines'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: balls, wins: const {'a': 1}))),
    );
    expect(find.text('90 lines · 1 win'), findsOneWidget);
    expect(find.text('out · 0 wins'), findsOneWidget);
  });

  testWidgets('scoreboard shows circular life meters in Arsenal', (tester) async {
    final a = _ball('a', 0)..life = 88;
    final b = _ball('b', 0)
      ..life = 0
      ..isEliminated = true;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: [a, b], mode: MatchMode.arsenal))));
    expect(find.text('88'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(CircularLifeMeter), findsNWidgets(2));
    expect(find.byType(HeartsRow), findsNothing);
    expect(
      tester.widget<CircularLifeMeter>(find.byType(CircularLifeMeter).first).life,
      88,
    );
  });

  testWidgets('Endless Battle scoreboard shows each ball knockout count', (tester) async {
    final balls = [_ball('a', 0)..life = 100, _ball('b', 0)..life = 100];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(
            balls: balls,
            mode: MatchMode.arsenal,
            eliminations: const {'a': 3},
          ),
        ),
      ),
    );
    expect(find.text('3 KOs'), findsOneWidget);
    expect(find.text('0 KOs'), findsOneWidget);
  });

  testWidgets('scoreboard shows equipped weapons and active power-ups', (tester) async {
    final ball = _ball('a', 0)
      ..life = 100
      ..held = PowerUpKind.pistol
      ..heldSecondary = PowerUpKind.sword
      ..speedLeft = 10
      ..goldenArmorHits = 2;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(balls: [ball], mode: MatchMode.arsenal),
        ),
      ),
    );
    expect(find.byType(PowerUpIcon), findsNWidgets(4));
    expect(find.bySemanticsLabel('Pistol'), findsOneWidget);
    expect(find.bySemanticsLabel('Sword'), findsOneWidget);
    expect(find.bySemanticsLabel('Speed'), findsOneWidget);
    expect(find.bySemanticsLabel('Golden Armor'), findsOneWidget);
  });

  testWidgets('circular life remains visible on a narrow scoreboard', (tester) async {
    tester.view.physicalSize = const Size(220, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final ball = _ball('a', 0)..life = 125;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(balls: [ball], mode: MatchMode.arsenal),
        ),
      ),
    );

    expect(find.text('125'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('All-Out hearts show the share of starting threads left', (tester) async {
    final a = _ball('a', 45)..startLines = 90;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScoreboardOverlay(balls: [a], mode: MatchMode.allOut))));
    expect(find.text('45 lines'), findsOneWidget);
    expect(tester.widget<HeartsRow>(find.byType(HeartsRow)).hearts, 5.0);
  });
}
