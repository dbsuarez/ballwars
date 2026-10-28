import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/audio/game_audio.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/skills/application/skill_demo_controller.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';

SkillDemoController demo(SkillDefinition skill) => SkillDemoController(
  skill: skill,
  library: SkillLibrary.defaults,
  tuning: PowerUpConfig.defaults,
);
void advance(SkillDemoController d, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    d.step(1 / 60);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('incoming test uses real enemy firing so Gremlin reverses the shot', () {
    final d = demo(
      SkillLibrary.defaults.builtIn(
        PowerUpKind.gremlin,
        PowerUpConfig.defaults,
      ),
    );
    d.incomingHit();
    advance(d, .1);
    expect(d.match.powerUps!.projectiles, isNotEmpty);
    expect(d.match.powerUps!.projectiles.first.velocity.dx, greaterThan(0));
  });
  test(
    'draft is equipped without firing; manual use and replay use current unsaved behavior',
    () {
      final original = SkillLibrary.defaults.builtIn(
        PowerUpKind.pistol,
        PowerUpConfig.defaults,
      );
      final draft = SkillLibrary.defaults
          .duplicate(original, 'Demo Draft')
          .copyWith(
            arsenalDamage: 7,
            castingSpriteId: 'custom.demo.cast',
            impactSpriteId: 'custom.demo.hit',
          );
      final d = demo(draft);
      expect(d.match.state.balls.first.heldSkillId, draft.id);
      expect(d.match.powerUps!.projectiles, isEmpty);
      expect(d.playing, false);
      d.activate();
      expect(d.match.powerUps!.castingArtwork.single.skill.id, draft.id);
      expect(d.match.powerUps!.projectiles, hasLength(1));
      advance(d, 2);
      expect(d.match.state.balls.last.life, 93);
      d.activate();
      advance(d, 2);
      expect(d.match.state.balls.last.life, 93);
      expect(SkillLibrary.defaults.custom, isEmpty);
      expect(
        SkillLibrary.defaults
            .builtIn(original.baseKind, PowerUpConfig.defaults)
            .arsenalDamage,
        original.arsenalDamage,
      );
    },
  );
  test(
    'recovery has missing health; pause/reset/facing are local and bounded',
    () {
      final d = demo(
        SkillLibrary.defaults.builtIn(
          PowerUpKind.apple,
          PowerUpConfig.defaults,
        ),
      );
      expect(d.match.state.balls.first.life, 45);
      d.activate();
      expect(d.match.state.balls.first.life, 70);
      d.playing = false;
      final before = d.elapsed;
      d.step(1);
      expect(d.elapsed, before);
      d.facingRight = false;
      d.reset();
      expect(d.match.state.balls.first.position.dx, greaterThan(0));
      expect(d.started, false);
    },
  );
  for (final kind in PowerUpKind.values) {
    test('manual demo supports ${kind.name} without random spawns', () {
      final d = demo(
        SkillLibrary.defaults.builtIn(kind, PowerUpConfig.defaults),
      );
      expect(() {
        d.activate();
        advance(d, 7);
      }, returnsNormally);
      expect(d.match.powerUps!.automaticSpawning, false);
      expect(d.match.state.balls, hasLength(2));
    });
  }
  test(
    'reactive custom effects can be auditioned once without enabling automatic triggers',
    () {
      final s = SkillLibrary.defaults
          .create('Reactive heal', PowerUpKind.apple)
          .copyWith(
            trigger: SkillTrigger.damageTaken,
            targeting: SkillTargeting.self,
            delivery: SkillDelivery.instant,
            effectType: SkillEffectType.heal,
            healing: 9,
          );
      final d = demo(s);
      d.activate();
      expect(d.match.state.balls.first.life, 54);
      advance(d, 2);
      expect(d.match.state.balls.first.life, 54);
    },
  );
  test(
    'incoming attack demonstrates a defensive power in the actual simulation',
    () {
      final d = demo(
        SkillLibrary.defaults.builtIn(
          PowerUpKind.goldenArmor,
          PowerUpConfig.defaults,
        ),
      );
      d.activate();
      d.incomingHit();
      advance(d, 2);
      expect(d.match.state.balls.first.life, 100);
      expect(d.match.state.balls.first.goldenArmorHits, lessThan(2));
    },
  );
  testWidgets(
    'phone demo shows all artwork slots, activates, pauses and keeps actions visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final audioEnabled = GameAudio.instance.enabled;
      GameAudio.instance.enabled = false;
      addTearDown(() => GameAudio.instance.enabled = audioEnabled);
      final skill = SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(yell: 'DRAFT SHOT!');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Scaffold(
            body: SkillDemoDialog(
              skill: skill,
              library: SkillLibrary.defaults,
              tuning: PowerUpConfig.defaults,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Casting', 'Equipped', 'Projectile', 'Impact']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('DRAFT SHOT!'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('use-demo-skill')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('use-demo-skill')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final canvas = tester.widget<ArenaCanvas>(
        find.byKey(const ValueKey('skill-demo-arena')),
      );
      expect(canvas.state.powerUps!.shots, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('pause-demo-skill')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Resume demo'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reset-demo-skill')));
      await tester.pumpAndSettle();
      expect(find.text('Use skill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
