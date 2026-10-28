import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/replay_export/data/saved_replay_store.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

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

/// Whether the End battle button reads [label] (as text, or in its tooltip when it is icon-only).
bool _shows(String label) =>
    find.text(label).evaluate().isNotEmpty ||
    find.byTooltip(label).evaluate().isNotEmpty;

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
      expect(find.text('ROUND START'), findsOneWidget);
      expect(find.byKey(const ValueKey('arena-sfx-control')), findsOneWidget);
      expect(find.byKey(const ValueKey('arena-bgm-control')), findsOneWidget);
      expect(find.byKey(const ValueKey('arena-ux-control')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('round-start-countdown')),
        findsOneWidget,
      );

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
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<Text>(find.byKey(const Key('match-timer'))).data,
        isNot(before),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Unstuck sits at the bottom left of the arena, in line with the sound buttons',
    (tester) async {
      await tester.pumpWidget(
        _app(const MatchConfig(contestants: _balls), seed: 3),
      );
      await tester.pump();
      final unstuck = find.byKey(const ValueKey('arena-unstuck'));
      expect(unstuck, findsOneWidget);
      final sound = find.byKey(const ValueKey('arena-bgm-control'));
      expect(
        tester.getCenter(unstuck).dx,
        lessThan(tester.getCenter(sound).dx),
      );
      expect(
        tester.getBottomLeft(unstuck).dy,
        closeTo(tester.getBottomLeft(sound).dy, 1),
      );
      await tester.tap(unstuck);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'End battle sits right of Unstuck in endless battles and ends at the next KO',
    (tester) async {
      await tester.pumpWidget(
        _app(
          const MatchConfig(
            contestants: _balls,
            mode: MatchMode.arsenal,
            endlessBattle: true,
          ),
          seed: 3,
        ),
      );
      await tester.pump();
      final unstuck = find.byKey(const ValueKey('arena-unstuck'));
      final end = find.byKey(const ValueKey('arena-end-battle'));
      expect(end, findsOneWidget);
      expect(_shows('End battle'), isTrue);
      expect(
        tester.getCenter(end).dx,
        greaterThan(tester.getCenter(unstuck).dx),
      );
      expect(
        tester.getBottomLeft(end).dy,
        closeTo(tester.getBottomLeft(unstuck).dy, 1),
      );
      await tester.tap(end);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_shows('Ending after next KO'), isTrue);
      expect(tester.widget<OutlinedButton>(end).onPressed, isNull);
      await _playUntilWinnerCard(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in const [Size(360, 800), Size(800, 360)]) {
    testWidgets(
      'End battle does not overlap the audio buttons on a ${size.width.toInt()}x${size.height.toInt()} phone',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            const MatchConfig(
              contestants: _balls,
              mode: MatchMode.arsenal,
              endlessBattle: true,
            ),
            seed: 3,
          ),
        );
        await tester.pump();
        final end = find.byKey(const ValueKey('arena-end-battle'));
        final unstuck = find.byKey(const ValueKey('arena-unstuck'));
        void expectNoOverlap() {
          final endRect = tester.getRect(end);
          expect(endRect.overlaps(tester.getRect(unstuck)), isFalse);
          for (final key in [
            'arena-bgm-control',
            'arena-sfx-control',
            'arena-ux-control',
          ]) {
            final audio = tester.getRect(find.byKey(ValueKey(key)));
            expect(
              endRect.overlaps(audio),
              isFalse,
              reason: '$key $audio vs end $endRect',
            );
          }
        }

        expectNoOverlap();
        await tester.tap(end);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_shows('Ending after next KO'), isTrue);
        expectNoOverlap();
        // Landscape phones already overflow vertically in every mode (outside this button's row), so
        // only portrait must be free of layout errors.
        final error = tester.takeException();
        if (size.width < size.height) expect(error, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'a replay with a recorded end step shows the ending label only from that step',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: const ArenaBattleScreen(
            config: MatchConfig(
              contestants: _balls,
              mode: MatchMode.arsenal,
              endlessBattle: true,
            ),
            seed: 3,
            endStep: 60,
          ),
        ),
      );
      await tester.pump();
      final end = find.byKey(const ValueKey('arena-end-battle'));
      expect(_shows('End battle'), isTrue);
      expect(_shows('Ending after next KO'), isFalse);
      expect(
        tester.widget<OutlinedButton>(end).onPressed,
        isNull,
        reason: 'a replay cannot be ended by hand',
      );
      // The 3 s countdown, then about a second of play reaches step 60.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_shows('End battle'), isTrue, reason: 'step 60 not reached yet');
      for (var i = 0; i < 40 && !_shows('Ending after next KO'); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_shows('Ending after next KO'), isTrue);
      expect(tester.widget<OutlinedButton>(end).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'End battle is not offered outside endless battles or in Mayhem',
    (tester) async {
      await tester.pumpWidget(
        _app(const MatchConfig(contestants: _balls), seed: 3),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('arena-end-battle')), findsNothing);
      await tester.pumpWidget(
        _app(
          const MatchConfig(
            contestants: _balls,
            mode: MatchMode.arsenal,
            endlessBattle: true,
            mayhem: true,
          ),
          seed: 3,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('arena-end-battle')), findsNothing);
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
    await tester.pump(const Duration(seconds: 4));
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
    expect(find.text('SERIES TALLY'), findsOneWidget);
    expect(find.byKey(const ValueKey('series-final-tally')), findsOneWidget);

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

  testWidgets(
    'Save replay: shown for a fresh match, hidden while watching a replay',
    (tester) async {
      await tester.pumpWidget(_app(const MatchConfig(contestants: _balls)));
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsOneWidget);

      // Replay of the finished round: no Save replay, Share link stays.
      await tester.tap(find.text('Replay'));
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsNothing);
      expect(find.text('Share'), findsOneWidget);

      // Play again starts a new match: Save replay returns.
      await tester.tap(find.text('Play again'));
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Save replay: hidden for a match opened from a link until Play again',
    (tester) async {
      await tester.pumpWidget(
        _app(const MatchConfig(contestants: _balls), seed: 3),
      );
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsNothing);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Replay'));
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsNothing);

      await tester.tap(find.text('Play again'));
      await tester.pump();
      await _playUntilWinnerCard(tester);
      expect(find.text('Save replay'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Share and Save replay explain a too-large skill snapshot instead of failing',
    (tester) async {
      var library = SkillLibrary.defaults;
      for (
        var i = 0;
        jsonEncode(library.toJson()).length <= SkillLibrary.maxReplayCharacters;
        i++
      ) {
        library = library.withDefinition(
          library
              .create('Story Skill $i', PowerUpKind.pistol)
              .copyWith(description: 'd' * 160),
          PowerUpConfig.defaults,
        );
      }
      expect(library.encodeReplay, throwsFormatException);

      final clipboard = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') clipboard.add(call.arguments);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      // No seed: a seeded screen counts as a replay and has no Save button.
      await tester.pumpWidget(
        _app(MatchConfig(contestants: _balls, skillLibrary: library)),
      );
      await tester.pump();
      await _playUntilWinnerCard(tester);

      await tester.tap(find.text('Share'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Too many custom skills to share this replay'),
        findsOneWidget,
      );
      expect(clipboard, isEmpty);

      ScaffoldMessenger.of(
        tester.element(find.byType(ArenaBattleScreen)),
      ).removeCurrentSnackBar();
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('save-replay')));
      await tester.tap(find.byKey(const ValueKey('save-replay')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Too many custom skills to share this replay'),
        findsOneWidget,
      );
      expect(await SavedReplayStore.load(), isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
