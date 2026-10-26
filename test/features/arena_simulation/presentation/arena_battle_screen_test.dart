import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

const _balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];

Widget _app(MatchConfig config, {int? seed}) => MaterialApp(
  theme: AppTheme.build(AppPalettes.midnight),
  home: ArenaBattleScreen(config: config, seed: seed),
);

/// Plays until the winner card (with its Exit button) is up, then lets its
/// entry animation finish.
Future<void> _playUntilWinnerCard(WidgetTester tester) async {
  for (var i = 0; i < 600 && find.text('Exit').evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(find.text('Exit'), findsOneWidget);
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'a fresh match shows the headline, round, both balls at half the rim and the timer',
    (tester) async {
      await tester.pumpWidget(_app(const MatchConfig(contestants: _balls)));
      await tester.pump();

      expect(find.text('WHO WINS?'), findsOneWidget);
      expect(find.text('ROUND 1'), findsOneWidget);
      // Each ball starts holding half of the 180 rim slots.
      expect(find.text('90 lines'), findsNWidgets(2));
      expect(find.text('0:00.0'), findsOneWidget);
      expect(find.text('Threads match'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'hidden arena stays stopped and resuming skips the background gap',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const MatchConfig(
            contestants: _balls,
            mode: MatchMode.arsenal,
            endlessBattle: true,
            mayhem: true,
            mayhemSeconds: 30,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mayhem match'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final before = tester
          .widget<Text>(find.byKey(const Key('match-timer')))
          .data;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 40));
      expect(
        tester.widget<Text>(find.byKey(const Key('match-timer'))).data,
        before,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 5));
      expect(
        tester.widget<Text>(find.byKey(const Key('match-timer'))).data,
        before,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Text>(find.byKey(const Key('match-timer'))).data,
        isNot(before),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pause button toggles between pause and play icons', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const MatchConfig(contestants: _balls)));
    await tester.pump();

    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shrinking arena shows its remaining size as a percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MatchConfig(contestants: _balls, shrinkingArena: true)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('arena-shrink-percent')), findsOneWidget);
    expect(find.text('ARENA 100%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the timer counts match time and New match resets it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MatchConfig(contestants: _balls), seed: 3),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0:00.0'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('restart-match')));
    await tester.pump();
    expect(find.text('0:00.0'), findsOneWidget);
    expect(find.text('90 lines'), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'winner card: "wins!", and New match (beside it) and Play again work',
    (tester) async {
      await tester.pumpWidget(
        _app(const MatchConfig(contestants: _balls), seed: 3),
      );
      await tester.pump();

      await _playUntilWinnerCard(tester);
      expect(find.text('wins!'), findsOneWidget);
      // The screen's own New match stays tappable under the card.
      expect(
        find.byKey(const ValueKey('restart-match')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('restart-match')));
      await tester.pump();
      expect(find.text('Exit'), findsNothing);
      expect(find.text('0:00.0'), findsOneWidget);

      await _playUntilWinnerCard(tester);
      await tester.tap(find.text('Play again'));
      await tester.pump();
      expect(find.text('Exit'), findsNothing);
      expect(find.text('0:00.0'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Replay plays the same match again: same winner, same match time',
    (tester) async {
      await tester.pumpWidget(
        _app(const MatchConfig(contestants: _balls), seed: 3),
      );
      await tester.pump();

      await _playUntilWinnerCard(tester);
      final time = tester.widget<Text>(find.textContaining('match time')).data;
      final winner = tester.widget<Text>(find.text('wins!').first);
      expect(winner, isNotNull);
      final names = [
        for (final b in _balls)
          if (find.text(b.name).evaluate().isNotEmpty) b.name,
      ];
      await tester.tap(find.text('Replay'));
      await tester.pump();
      expect(find.text('0:00.0'), findsOneWidget);

      await _playUntilWinnerCard(tester);
      expect(tester.widget<Text>(find.textContaining('match time')).data, time);
      expect([
        for (final b in _balls)
          if (find.text(b.name).evaluate().isNotEmpty) b.name,
      ], names);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('first-to-2 series: round result, Next round, round counter', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const MatchConfig(contestants: _balls, winsNeeded: 2), seed: 3),
    );
    await tester.pump();
    expect(find.text('ROUND 1 · FIRST TO 2'), findsOneWidget);

    await _playUntilWinnerCard(tester);
    expect(find.text('wins round 1'), findsOneWidget);
    expect(
      find.textContaining('A  '),
      findsOneWidget,
    ); // score line, e.g. "A  1   ·   B  0"

    await tester.tap(find.text('Next round'));
    await tester.pump();
    expect(find.text('ROUND 2 · FIRST TO 2'), findsOneWidget);
    expect(find.text('Exit'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the arena fills its space on phones and wide screens', (
    tester,
  ) async {
    for (final size in const [Size(390, 844), Size(1280, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(const MatchConfig(contestants: _balls)));
      await tester.pump();
      final arena = tester.getSize(find.byType(ArenaCanvas));
      expect(arena.shortestSide, greaterThan(300), reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    tester.view.reset();
  });

  testWidgets('an Arsenal match shows life in the scoreboard', (tester) async {
    await tester.pumpWidget(
      _app(const MatchConfig(contestants: _balls, mode: MatchMode.arsenal)),
    );
    await tester.pump();
    expect(find.text('100'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a question replaces the headline and the winner card gives the answer',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const MatchConfig(contestants: _balls, question: 'Will it rain?'),
          seed: 3,
        ),
      );
      await tester.pump();
      expect(find.text('Will it rain?'), findsOneWidget);
      await _playUntilWinnerCard(tester);
      expect(find.textContaining('Answer: '), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
