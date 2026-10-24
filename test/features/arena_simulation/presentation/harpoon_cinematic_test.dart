import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('harpoon cinematic pulls a dizzy loser into an uppercut', (
    tester,
  ) async {
    var finished = false;
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
        ),
      ),
    );

    expect(find.text('COME OVER HERE!'), findsOneWidget);
    expect(find.text('FINISHING MOVE'), findsOneWidget);
    expect(find.text('★  ×  ★'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('UPPERCUT!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(finished, isTrue);
  });
}
