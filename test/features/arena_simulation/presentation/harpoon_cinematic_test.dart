import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
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
}
