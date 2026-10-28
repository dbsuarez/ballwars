import 'dart:ui' show PictureRecorder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/arena_simulation/presentation/scoreboard_overlay.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';

SimulationBall _ball(String id, int lines) => SimulationBall(
  config: CustomBall(
    id: id,
    name: id.toUpperCase(),
    primaryColor: Colors.red,
    glowColor: Colors.pink,
  ),
  position: Offset.zero,
  velocity: Offset.zero,
  radius: 20,
  lineCount: lines,
);

void main() {
  testWidgets(
    'real match strip resolves both same-kind weapons by their own IDs',
    (tester) async {
      final knife = SkillLibrary.defaults.builtIn(
        PowerUpKind.knife,
        PowerUpConfig.defaults,
      );
      final custom = SkillLibrary.defaults
          .duplicate(knife, 'Kutsilyo')
          .copyWith(spriteTint: 0xffffcc00);
      final library = SkillLibrary.defaults.withDefinition(
        custom,
        PowerUpConfig.defaults,
      );
      final ball = _ball('a', 5)
        ..held = PowerUpKind.knife
        ..heldSkillId = custom.id
        ..heldSecondary = PowerUpKind.knife
        ..heldSecondarySkillId = knife.id;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreboardOverlay(
              balls: [ball],
              mode: MatchMode.arsenal,
              skillById: (id) => library.byId(id, PowerUpConfig.defaults),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kutsilyo'), findsOneWidget);
      expect(find.text('Knife'), findsOneWidget);
      final icons = tester
          .widgetList<PowerUpIcon>(find.byType(PowerUpIcon))
          .toList();
      expect(icons.map((icon) => icon.tint), [
        custom.spriteTint,
        knife.spriteTint,
      ]);
    },
  );
  test('secondary-only equipment artwork keeps its actual slot index', () {
    final ball = _ball('a', 5)..heldSecondary = PowerUpKind.knife;
    final slots = <int>[];
    final recorder = PictureRecorder();
    PowerUpPainter.paintBallEffects(
      Canvas(recorder),
      ball,
      artworkTint: (_, slot) {
        slots.add(slot);
        return 0xffffffff;
      },
      useWeaponSprite: (_, _) => false,
    );
    recorder.endRecording().dispose();
    expect(slots, [1]);
  });
  testWidgets('a held custom skill shows its own tier color in the strip', (
    tester,
  ) async {
    const tuning = PowerUpConfig.defaults;
    final kutsilyo = SkillLibrary.withOwnRarity(
      SkillLibrary.defaults.create('Kutsilyo', PowerUpKind.knife),
      PowerUpRarity.special,
      tuning,
    );
    final controller = MatchSimulationController(
      const [
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
      ],
      arenaRadius: 260,
      seed: 1,
      mode: MatchMode.arsenal,
      lookAhead: false,
      skillLibrary: SkillLibrary.defaults.withDefinition(kutsilyo, tuning),
    );
    final [a, b] = controller.state.balls;
    a
      ..held = PowerUpKind.knife
      ..heldSkillId = kutsilyo.id;
    b.held = PowerUpKind.knife;

    Color? colorIn(String id) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('equipment-strip-$id')),
            matching: find.text('Knife'),
          ),
        )
        .style
        ?.color;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(
            balls: [a, b],
            mode: MatchMode.arsenal,
            itemRarity: (ball, kind) =>
                controller.powerUps!.itemRarity(kind, ball: ball),
          ),
        ),
      ),
    );
    expect(colorIn('a'), PowerUpRarity.special.color);
    // The built-in Knife keeps its Normal tier.
    expect(colorIn('b'), PowerUpRarity.normal.color);
  });

  testWidgets('shows each ball with its lines, and round wins in a series', (
    tester,
  ) async {
    final balls = [_ball('a', 90), _ball('b', 45)..isEliminated = true];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScoreboardOverlay(balls: balls)),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('90 lines'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(balls: balls, wins: const {'a': 1}),
        ),
      ),
    );
    expect(find.text('90 lines · 1 win'), findsOneWidget);
    expect(find.text('out · 0 wins'), findsOneWidget);
  });

  testWidgets('scoreboard shows circular life meters in Arsenal', (
    tester,
  ) async {
    final a = _ball('a', 0)..life = 88;
    final b = _ball('b', 0)
      ..life = 0
      ..isEliminated = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(balls: [a, b], mode: MatchMode.arsenal),
        ),
      ),
    );
    expect(find.text('88'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(CircularLifeMeter), findsNWidgets(2));
    expect(find.byType(HeartsRow), findsNothing);
    expect(
      tester
          .widget<CircularLifeMeter>(find.byType(CircularLifeMeter).first)
          .life,
      88,
    );
  });

  testWidgets('Endless Battle scoreboard shows each ball knockout count', (
    tester,
  ) async {
    final balls = [_ball('a', 0)..life = 100, _ball('b', 0)..life = 100];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(
            balls: balls,
            mode: MatchMode.arsenal,
            eliminations: const {'a': 3},
            deaths: const {'a': 2, 'b': 4},
          ),
        ),
      ),
    );
    expect(find.text('3 W'), findsOneWidget);
    expect(find.text('0 W'), findsOneWidget);
    expect(find.text('2 L'), findsOneWidget);
    expect(find.text('4 L'), findsOneWidget);
  });

  testWidgets('scoreboard shows equipped weapons and active power-ups', (
    tester,
  ) async {
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
    expect(find.text('Pistol'), findsOneWidget);
    expect(find.text('Sword'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Golden Armor'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('equipment-strip-a'))).height,
      24,
    );
  });

  testWidgets(
    'scoreboard reserves the equipment row when nothing is equipped',
    (tester) async {
      final ball = _ball('a', 0)..life = 100;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScoreboardOverlay(balls: [ball], mode: MatchMode.arsenal),
          ),
        ),
      );

      expect(find.byType(PowerUpIcon), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('equipment-strip-a'))).height,
        24,
      );
    },
  );

  testWidgets('circular life remains visible on a narrow scoreboard', (
    tester,
  ) async {
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

  testWidgets('All-Out hearts show the share of starting threads left', (
    tester,
  ) async {
    final a = _ball('a', 45)..startLines = 90;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScoreboardOverlay(balls: [a], mode: MatchMode.allOut),
        ),
      ),
    );
    expect(find.text('45 lines'), findsOneWidget);
    expect(tester.widget<HeartsRow>(find.byType(HeartsRow)).hearts, 5.0);
  });
  testWidgets('six-player mobile scoreboard fits compact cards in two rows', (
    tester,
  ) async {
    final balls = [
      for (var i = 0; i < 6; i++) _ball('player$i', 0)..life = 100,
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: ScoreboardOverlay(
                compact: true,
                balls: balls,
                mode: MatchMode.arsenal,
                eliminations: const {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Card), findsNWidgets(6));
    expect(find.text('100 HP / 0 W'), findsNWidgets(6));
    expect(
      tester.getSize(find.byType(ScoreboardOverlay)).height,
      lessThan(220),
    );
    expect(tester.takeException(), isNull);
  });
}
