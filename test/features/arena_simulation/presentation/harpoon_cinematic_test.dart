import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/arena_simulation/presentation/finisher_profile.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'harpoon cinematic shows smiley effects and timed action sounds',
    (tester) async {
      var finished = false;
      var hookSounds = 0;
      var impacts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: HarpoonCinematic(
            winner: const CustomBall(
              id: 'a',
              name: 'Ball A',
              primaryColor: Colors.red,
              glowColor: Colors.pink,
            ),
            loser: const CustomBall(
              id: 'b',
              name: 'Ball B',
              primaryColor: Colors.blue,
              glowColor: Colors.cyan,
            ),
            move: 'Hook',
            onFinished: () => finished = true,
            onHookFired: () => hookSounds++,
            onImpact: () => impacts++,
          ),
        ),
      );

      expect(find.text('COME OVER HERE!'), findsOneWidget);
      expect(find.text('FINISHING MOVE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('harpoon-cinematic-effects')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 1400));
      expect(hookSounds, 1);
      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('UPPERCUT!'), findsOneWidget);
      expect(impacts, 1);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(finished, isTrue);
    },
  );

  test('every weapon, power-up, and trap has a finisher profile', () {
    expect(FinisherProfile.coversEveryDamagingArenaItem, isTrue);
  });

  test('Energy Wave uses its beam renderer instead of a letter glyph', () {
    expect(FinisherProfile.forMove('Energy Wave').symbol, isEmpty);
  });

  testWidgets('grenade uses its own blast finisher instead of the hook move', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: HarpoonCinematic(
          winner: const CustomBall(
            id: 'a',
            name: 'Ball A',
            primaryColor: Colors.red,
            glowColor: Colors.pink,
          ),
          loser: const CustomBall(
            id: 'b',
            name: 'Ball B',
            primaryColor: Colors.blue,
            glowColor: Colors.cyan,
          ),
          move: 'Grenade',
          onFinished: () {},
        ),
      ),
    );

    expect(find.text('FIRE IN THE HOLE!'), findsOneWidget);
    expect(FinisherProfile.forMove('Grenade').style, FinisherStyle.blast);
    await tester.pump(const Duration(milliseconds: 3300));
    expect(find.text('KABOOM!'), findsOneWidget);
    expect(find.text('UPPERCUT!'), findsNothing);
  });
  testWidgets('Skip completes a finisher exactly once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(MaterialApp(home: HarpoonCinematic(
      winner: const CustomBall(id: 'a', name: 'A', primaryColor: Colors.red, glowColor: Colors.red),
      loser: const CustomBall(id: 'b', name: 'B', primaryColor: Colors.blue, glowColor: Colors.blue),
      move: 'Hook', onFinished: () => finished++,
    )));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('skip-finisher')));
    await tester.pump(const Duration(seconds: 5));
    expect(finished, 1);
  });

}
