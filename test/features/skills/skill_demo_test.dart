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
  test('fresh replay resets prior event counters and projectile state', () {
    final d = demo(SkillLibrary.defaults.create('Replay shot', PowerUpKind.pistol).copyWith(
      delivery: SkillDelivery.projectile,
      startDelaySeconds: 0,
      effectSteps: const [SkillEffectStep(type: SkillEffectType.damage, damage: 4)],
    ));
    d.activate();
    advance(d, .1);
    final firstShots = d.match.powerUps!.shots;
    expect(firstShots, greaterThan(0));
    d.activate();
    expect(d.match.powerUps!.shots, lessThanOrEqualTo(firstShots));
    expect(d.elapsed, 0);
  });

  test('a completed event replay remains bounded until explicitly replayed', () {
    final d = demo(SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    ));
    d.activate();
    advance(d, d.duration + 1);
    expect(d.playing, isFalse);
    expect(d.elapsed, greaterThanOrEqualTo(d.duration));
    final finishedTime = d.elapsed;
    d.step(1);
    expect(d.elapsed, finishedTime);
    d.activate();
    expect(d.elapsed, 0);
    expect(d.playing, isTrue);
  });

  test('preview pickup uses isolated arena field and can be cleared', () {
    final skill = SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    final d = demo(skill);
    expect(d.hasPreviewPickup, isFalse);
    d.spawnPreviewPickup();
    expect(d.hasPreviewPickup, isTrue);
    expect(d.match.powerUps!.field, hasLength(1));
    final pickup = d.match.powerUps!.field.single;
    expect(pickup.skillId, skill.id);
    expect(pickup.position.dx, 0);
    expect(pickup.position.dy, lessThan(0));
    expect(pickup.position.dy.abs(), lessThan(d.match.arenaRadius));
    d.spawnPreviewPickup();
    expect(d.match.powerUps!.field, hasLength(1));
    d.clearPreviewPickup();
    expect(d.hasPreviewPickup, isFalse);
    d.spawnPreviewPickup();
    d.reset();
    expect(d.hasPreviewPickup, isFalse);
  });

  test('stopping replay for pickup inspection preserves field objects', () {
    final d = demo(SkillLibrary.defaults.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    ));
    d.activate();
    expect(d.playing, isTrue);
    d.spawnPreviewPickup();
    d.stopPlayback();
    expect(d.playing, isFalse);
    expect(d.started, isFalse);
    expect(d.elapsed, 0);
    expect(d.hasPreviewPickup, isTrue);
    d.clearPreviewPickup();
    expect(d.hasPreviewPickup, isFalse);
  });

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
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('DRAFT SHOT!'), findsOneWidget);
       // Focus actions must be reachable and perform their advertised action.
       final focus = find.byKey(
         const ValueKey('skill-demo-preview-focused-artwork'),
       );
       await tester.ensureVisible(focus);
       await tester.pumpAndSettle();
       expect(find.text('Show pickup in arena'), findsOneWidget);
       await tester.tap(focus);
       await tester.pump();
       final pickupCanvas = tester.widget<ArenaCanvas>(
         find.byKey(const ValueKey('skill-demo-arena')),
       );
       expect(pickupCanvas.state.powerUps!.field, hasLength(1));
       // Direct arena controls must also clear any pending replay state.
       await tester.ensureVisible(find.byKey(const ValueKey('skill-demo-clear-pickup')));
       await tester.tap(find.byKey(const ValueKey('skill-demo-clear-pickup')));
       await tester.pump();
       final clearedCanvas = tester.widget<ArenaCanvas>(
         find.byKey(const ValueKey('skill-demo-arena')),
       );
       expect(clearedCanvas.state.powerUps!.field, isEmpty);
       final spawnPickup = find.byKey(const ValueKey('skill-demo-spawn-pickup'));
       await tester.ensureVisible(spawnPickup);
       await tester.pumpAndSettle();
       expect(spawnPickup.hitTestable(), findsOneWidget);
       await tester.tap(spawnPickup);
       await tester.pump();
       expect(tester.widget<ArenaCanvas>(find.byKey(const ValueKey('skill-demo-arena')))
           .state.powerUps!.field, hasLength(1));

       // Equipped mode must not fire a shot just to inspect held artwork.
       await tester.ensureVisible(find.byKey(const ValueKey('skill-demo-mode-equipped')));
       await tester.tap(find.byKey(const ValueKey('skill-demo-mode-equipped')));
       await tester.pump();
       expect(find.text('Inspect equipped in arena'), findsOneWidget);
       await tester.tap(focus);
       await tester.pump();
       final equippedCanvas = tester.widget<ArenaCanvas>(
         find.byKey(const ValueKey('skill-demo-arena')),
       );
       expect(equippedCanvas.state.powerUps!.shots, 0);
       expect(equippedCanvas.state.powerUps!.projectiles, isEmpty);
       expect(equippedCanvas.state.powerUps!.field, isEmpty);

       await tester.ensureVisible(
         find.byKey(const ValueKey('skill-demo-mode-projectile')),
       );
       await tester.pumpAndSettle();
       await tester.tap(find.byKey(const ValueKey('skill-demo-mode-projectile')));
       await tester.pump();
       expect(find.text('Replay to first projectile'), findsOneWidget);
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
      // Event-focused Projectile mode may already have paused itself on
      // the first shot. Do not accidentally resume it by tapping Pause.
      final pauseButton = find.byKey(const ValueKey('pause-demo-skill'));
      final pauseTooltip = tester.widget<Tooltip>(
        find.descendant(of: pauseButton, matching: find.byType(Tooltip)).first,
      );
      if (pauseTooltip.message == 'Pause demo') {
        await tester.tap(pauseButton);
        await tester.pump();
      }
      expect(find.byTooltip('Resume demo'), findsOneWidget);
      final inspector = find.byKey(const ValueKey('skill-demo-inspector'));
      await tester.ensureVisible(inspector);
      await tester.pumpAndSettle();
      await tester.tap(inspector);
      await tester.pumpAndSettle();
      expect(find.textContaining('Active sources:'), findsOneWidget);
      expect(find.textContaining('physical areas'), findsOneWidget);
      expect(find.textContaining('started'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('reset-demo-skill')));
      await tester.pumpAndSettle();
      expect(find.text('Use skill'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
