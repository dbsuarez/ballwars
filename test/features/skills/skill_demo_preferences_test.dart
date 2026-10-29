import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/skills/application/skill_demo_controller.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  test('demo duration accounts for ordered-step delays without removing the 45-second cap', () {
    final skill = SkillLibrary.defaults.create('Delayed test', PowerUpKind.pistol).copyWith(
      effectSteps: const [SkillEffectStep(type: SkillEffectType.damage, delaySeconds: 10, durationSeconds: 2)],
    );
    final demo = SkillDemoController(skill: skill, library: SkillLibrary.defaults, tuning: PowerUpConfig.defaults);
    expect(demo.duration, greaterThan(12));
    final longSkill = skill.copyWith(effectSteps: List.filled(8, const SkillEffectStep(type: SkillEffectType.damage, delaySeconds: 10)));
    final longDemo = SkillDemoController(skill: longSkill, library: SkillLibrary.defaults, tuning: PowerUpConfig.defaults);
    expect(longDemo.duration, 45);
    expect(longDemo.timeLimited, isTrue);
  });
  test(
    'near to far spacing is bounded, survives reset and respects facing',
    () {
      final skill = SkillLibrary.defaults.builtIn(
        PowerUpKind.pistol,
        PowerUpConfig.defaults,
      );
      final demo = SkillDemoController(
        skill: skill,
        library: SkillLibrary.defaults,
        tuning: PowerUpConfig.defaults,
      );
      demo.distanceRatio = 0;
      demo.reset();
      final near =
          demo.match.state.balls.last.position.dx -
          demo.match.state.balls.first.position.dx;
      demo.distanceRatio = 1;
      demo.reset();
      final a = demo.match.state.balls.first, b = demo.match.state.balls.last;
      expect(b.position.dx - a.position.dx, greaterThan(near));
      expect(b.position.distance + b.radius, lessThan(demo.match.arenaRadius));
      expect(
        (a.position - b.position).distance,
        greaterThan(a.radius + b.radius),
      );
      demo.facingRight = false;
      demo.reset();
      expect(demo.match.state.balls.first.position.dx, greaterThan(0));
      expect(demo.distanceRatio, 1);
    },
  );
  testWidgets(
    'demo remembers sound, inspector, facing, speed and distance after reopen',
    (tester) async {
      Future<void> open() async {
        await tester.pumpWidget(
          MaterialApp(
            home: SkillDemoDialog(
              skill: SkillLibrary.defaults.builtIn(
                PowerUpKind.pistol,
                PowerUpConfig.defaults,
              ),
              library: SkillLibrary.defaults,
              tuning: PowerUpConfig.defaults,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.byKey(const ValueKey('skill-demo-sound')));
      await tester.pumpAndSettle();
      tester
          .widget<SwitchListTile>(
            find.byKey(const ValueKey('skill-demo-inspector')),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .onSelectionChanged!({false});
      tester
          .widget<DropdownButton<double>>(
            find.byKey(const ValueKey('skill-demo-speed')),
          )
          .onChanged!(.25);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Far'));
      await tester.tap(find.text('Far'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await open();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('skill-demo-sound')))
            .tooltip,
        'Enable demo sound',
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('skill-demo-inspector')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('skill-demo-distance')))
            .value,
        1,
      );
      expect(
        tester
            .widget<DropdownButton<double>>(
              find.byKey(const ValueKey('skill-demo-speed')),
            )
            .value,
        .25,
      );
      final canvas = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
      expect(canvas.state.balls.first.position.dx, greaterThan(0));
    },
  );
}
