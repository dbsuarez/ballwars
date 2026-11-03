import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/grip_preview_dialog.dart';

void main() {
  testWidgets('grip preview remains visible while lower controls scroll', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: GripPreviewDialog(
            kind: PowerUpKind.sword,
            grip: GripValues(attackAnimation: HeldAttackAnimation.slash),
          ),
        ),
      ),
    ));
    await tester.pump();
    final preview = find.byKey(const ValueKey('grip-preview-right'));
    final before = tester.getTopLeft(preview);
    final facing = find.byKey(const ValueKey('grip-preview-facing'));
    await tester.scrollUntilVisible(facing, 250,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('grip-preview-settings-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    expect(preview, findsOneWidget);
    expect(tester.getTopLeft(preview), before,
      reason: 'preview stays pinned while lower settings scroll');
  });


  test('drag offsets affect only the selected artwork layer', () {
    const initial = GripValues(
      heldOffsetX: 0.25, heldOffsetY: 0.5,
      effectOffsetX: -0.25, effectOffsetY: -0.5,
    );
    final held = initial.movedBy(0.5, -0.25, effect: false);
    expect(held.heldOffsetX, 0.75);
    expect(held.heldOffsetY, 0.25);
    expect(held.effectOffsetX, -0.25);
    expect(held.effectOffsetY, -0.5);
    final effect = held.movedBy(-0.5, 0.5, effect: true);
    expect(effect.heldOffsetX, 0.75);
    expect(effect.effectOffsetX, -0.75);
    expect(effect.effectOffsetY, 0);
  });

  test('drag offsets clamp and ignore nonfinite deltas', () {
    const initial = GripValues();
    final clamped = initial.movedBy(100, -100, effect: false);
    expect(clamped.heldOffsetX, 1.5);
    expect(clamped.heldOffsetY, -1.5);
    expect(clamped.movedBy(double.nan, 1, effect: true), same(clamped));
  });

  test('live preview retains independent held and effect positioning', () {
    const initial = GripValues();
    final edited = initial.copyWith(
      heldAttachment: 'left',
      effectAttachment: 'both',
      heldOffsetX: 0.5,
      heldOffsetY: -0.25,
      effectOffsetX: -0.4,
      effectOffsetY: 0.75,
      pickupScale: 1.5,
    );
    expect(initial.heldAttachment, 'right');
    expect(initial.heldOffsetX, 0);
    expect(edited.heldAttachment, 'left');
    expect(edited.effectAttachment, 'both');
    expect(edited.heldOffsetX, 0.5);
    expect(edited.heldOffsetY, -0.25);
    expect(edited.effectOffsetX, -0.4);
    expect(edited.effectOffsetY, 0.75);
    expect(edited.pickupScale, 1.5);
    expect(edited.copyWith(heldOffsetY: 0.0).effectOffsetX, -0.4);
  });
}
