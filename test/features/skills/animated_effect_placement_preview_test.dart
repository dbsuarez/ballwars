import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_visual_effect.dart';
import 'package:ballwars/features/skills/presentation/effect_placement_preview.dart';

void main() {
  testWidgets('animated placement preview can pause, step and resume',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AnimatedEffectPlacementPreview(
          effect: null,
          role: SkillVisualRole.muzzle,
          height: 90,
        ),
      ),
    ));
    expect(find.text('Choose artwork to see its placement.'), findsOneWidget);
    final play = find.byKey(const ValueKey('visual-preview-play-muzzle'));
    final step = find.byKey(const ValueKey('visual-preview-step-muzzle'));
    expect(play, findsOneWidget);
    expect(find.text('Frame 1/8'), findsOneWidget);
    expect(step, findsOneWidget);
    // The editor must settle without an active repeating ticker.
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(step);
    await tester.pump();
    expect(find.text('Frame 2/8'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(play);
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(play);
    await tester.pump();
    // Disposing a playing preview must not leak a scheduled ticker.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
