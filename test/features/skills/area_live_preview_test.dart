import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/area_effect_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('area preview accepts live radius and boundary changes',
      (tester) async {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.molotov, PowerUpConfig.defaults);
    Widget preview(double radius, AreaGuideStyle style, double opacity) =>
        MaterialApp(
          home: Scaffold(
            body: AreaEffectPreview(
              skill: skill.copyWith(
                areaGuideStyle: style,
                areaGuideOpacity: opacity,
              ),
              library: SkillLibrary.defaults,
              radiusRatio: radius,
            ),
          ),
        );

    await tester.pumpWidget(preview(.2, AreaGuideStyle.hidden, .3));
    expect(find.byType(AreaEffectPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(preview(.5, AreaGuideStyle.dashed, .7));
    expect(tester.widget<AreaEffectPreview>(find.byType(AreaEffectPreview))
        .radiusRatio, .5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(preview(.9, AreaGuideStyle.solid, 1));
    expect(tester.widget<AreaEffectPreview>(find.byType(AreaEffectPreview))
        .skill.areaGuideStyle, AreaGuideStyle.solid);
    expect(tester.takeException(), isNull);
  });

  testWidgets('radius drag changes the draft radius only when enabled',
      (tester) async {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.molotov, PowerUpConfig.defaults);
    double radius = .3;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, refresh) =>
        AreaEffectPreview(
          skill: skill,
          library: SkillLibrary.defaults,
          radiusRatio: radius,
          onRadiusChanged: (next) => refresh(() => radius = next),
        ),
      )),
    ));
    final drag = find.byKey(const ValueKey('skill-area-radius-drag'));
    expect(drag, findsOneWidget);
    await tester.drag(drag, const Offset(80, 0));
    await tester.pump();
    expect(radius, greaterThan(.3));
    expect(tester.takeException(), isNull);
  });

}

// The radius drag uses the existing custom-radius setting, rather than
// introducing a second gameplay offset or silently persisting preview edits.
