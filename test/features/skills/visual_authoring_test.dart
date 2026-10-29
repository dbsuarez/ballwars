import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/replay_export/domain/replay_link.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';

const tuning = PowerUpConfig.defaults;
const balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.red,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.blue,
  ),
];
MatchSimulationController match(SkillDefinition skill) {
  final m = MatchSimulationController(
    balls,
    mode: MatchMode.arsenal,
    arenaRadius: 180,
    lookAhead: false,
    automaticSpeedUp: false,
    seed: 1,
    skillLibrary: SkillLibrary.defaults.withDefinition(skill, tuning),
  );
  m.powerUps!.automaticSpawning = false;
  m.state.balls.first
    ..position = const Offset(-50, 0)
    ..velocity = Offset.zero;
  m.state.balls.last
    ..position = const Offset(50, 0)
    ..velocity = Offset.zero;
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('origin and area overrides survive full, compact and replay saves', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.pistol, tuning)
        .copyWith(
          projectileOriginForward: 2.25,
          projectileOriginSide: -.4,
          areaRadiusRatio: .3,
          areaGuideStyle: AreaGuideStyle.hidden,
          areaGuideOpacity: .2,
        );
    final library = SkillLibrary.defaults.withDefinition(skill, tuning);
    expect(library.toJson()['version'], 10);
    expect(library.toCompactJson()['version'], 11);
    for (final j in [library.toJson(), library.toCompactJson()]) {
      final read = SkillLibrary.importJson(
        jsonEncode(j),
      ).builtIn(PowerUpKind.pistol, tuning);
      expect(read.projectileOriginForward, 2.25);
      expect(read.projectileOriginSide, -.4);
      expect(read.areaRadiusRatio, .3);
      expect(read.areaGuideStyle, AreaGuideStyle.hidden);
      expect(read.areaGuideOpacity, .2);
    }
    expect(
      skill
          .copyWith(projectileOriginForward: null, areaRadiusRatio: null)
          .projectileOriginForward,
      isNull,
    );
  });
  for (final kind in [
    PowerUpKind.pistol,
    PowerUpKind.molotov,
    PowerUpKind.rocketLauncher,
  ]) {
    test('${kind.name} uses the actual configured launch point', () {
      final skill = SkillLibrary.defaults
          .builtIn(kind, tuning)
          .copyWith(projectileOriginForward: 2, projectileOriginSide: .5);
      final m = match(skill), b = m.state.balls.first;
      m.powerUps!.activateTestSkill(b, skill, m.state.balls.last);
      m.tick(1 / 60);
      final shot = m.powerUps!.projectiles.first;
      expect(shot.position, b.position + Offset(2 * b.radius, .5 * b.radius));
    });
  }
  test(
    'custom area radius controls real targeting, separate from ground artwork',
    () {
      const skill = SkillDefinition(
        id: 'custom.area',
        name: 'Area',
        custom: true,
        baseKind: PowerUpKind.apple,
        trigger: SkillTrigger.pickup,
        targeting: SkillTargeting.allOpponents,
        delivery: SkillDelivery.area,
        effectType: SkillEffectType.damage,
        arsenalDamage: 7,
        areaRadiusRatio: .2,
      );
      final m = match(skill),
          b = m.state.balls.first,
          target = m.state.balls.last;
      b.position = Offset.zero;
      target.position = const Offset(20, 0);
      m.powerUps!.activateTestSkill(b, skill, target);
      expect(target.life, 93);
      m.powerUps!.persistentEffects.sync();
      expect(
        m.powerUps!.persistentEffects.handles
            .singleWhere((e) => e.activation)
            .radius(),
        36,
      );
      final outside = match(skill);
      outside.powerUps!.activateTestSkill(
        outside.state.balls.first,
        skill,
        outside.state.balls.last,
      );
      expect(outside.state.balls.last.life, 100);
    },
  );
  test('custom shotgun launches a whole volley from one barrel point', () {
    final skill = SkillLibrary.defaults
        .builtIn(PowerUpKind.shotgun, tuning)
        .copyWith(projectileOriginForward: 2, projectileOriginSide: .5);
    final m = match(skill), b = m.state.balls.first;
    m.powerUps!.activateTestSkill(b, skill, m.state.balls.last);
    m.tick(1 / 60);
    expect(m.powerUps!.projectiles.length, greaterThan(1));
    expect(m.powerUps!.projectiles.map((p) => p.position).toSet(), {
      b.position + Offset(2 * b.radius, .5 * b.radius),
    });
  });
  test('replay includes a validated revision manifest and rejects tampering', () {
    const old = 'custom.00000000-0000-0000-0000-000000000001.icon';
    const pinned =
        'custom.00000000-0000-0000-0000-000000000001~00000000-0000-0000-0000-000000000002.icon';
    final lib = SkillLibrary.defaults
        .withDefinition(
          SkillLibrary.defaults
              .builtIn(PowerUpKind.pistol, tuning)
              .copyWith(iconSpriteId: old),
          tuning,
        )
        .remapArtwork({old: pinned});
    final uri = ReplayLink(
      seed: 1,
      speedMultiplier: 1,
      contestants: balls,
      mode: MatchMode.arsenal,
      skillLibrary: lib,
      artworkRevisions: const {old: pinned},
    ).toUri(presetIds: {'a', 'b'});
    final read = ReplayLink.fromUri(uri, presets: balls)!;
    expect(read.artworkRevisions, {old: pinned});
    expect(
      read.skillLibrary.builtIn(PowerUpKind.pistol, tuning).iconSpriteId,
      pinned,
    );
    expect(
      ReplayLink.fromUri(
        uri.replace(queryParameters: {...uri.queryParameters, 'assets': 'bad'}),
        presets: balls,
      ),
      isNull,
    );
  });
  testWidgets('Skill Demo remembers the speed across reopen and reset', (
    tester,
  ) async {
    final previous = OfflineStore.instance;
    OfflineStore.instance = MemoryOfflineStore();
    addTearDown(() => OfflineStore.instance = previous);
    await DevicePrefs.write('skill-demo-speed', .5);
    Future<void> open() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Scaffold(
            body: SkillDemoDialog(
              skill: SkillLibrary.defaults.builtIn(PowerUpKind.pistol, tuning),
              library: SkillLibrary.defaults,
              tuning: tuning,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open();
    final selector = find.byKey(const ValueKey('skill-demo-speed'));
    expect(tester.widget<DropdownButton<double>>(selector).value, .5);
    tester.widget<DropdownButton<double>>(selector).onChanged!(.25);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await open();
    expect(tester.widget<DropdownButton<double>>(selector).value, .25);
    await tester.tap(find.byKey(const ValueKey('reset-demo-skill')));
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<double>>(selector).value, .25);
  });
  testWidgets(
    'phone editor previews and saves launch point and reusable area settings',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: tuning,
            onSave: (result) async => saved = result,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Molotov',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Molotov'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Appearance'));
      await tester.tap(find.widgetWithText(Tab, 'Appearance'));
      await tester.pumpAndSettle();
      Future<void> reveal(Finder f) async {
        await tester.scrollUntilVisible(
          f,
          300,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 35,
        );
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
      }

      final origin = find.byKey(const ValueKey('skill-custom-origin'));
      await reveal(origin);
      await tester.tap(origin);
      await tester.pumpAndSettle();
      final forward = find.byKey(const ValueKey('skill-slider-originForward'));
      await reveal(forward);
      tester.widget<Slider>(forward).onChanged!(2);
      await tester.pump();
      final side = find.byKey(const ValueKey('skill-slider-originSide'));
      await reveal(side);
      tester.widget<Slider>(side).onChanged!(-.25);
      await tester.pump();
      final areaPreview = find.byKey(const ValueKey('skill-area-preview'));
      await reveal(areaPreview);
      expect(tester.getSize(areaPreview).width, greaterThan(200));
      final radius = find.byKey(const ValueKey('skill-area-radius-override'));
      await reveal(radius);
      await tester.tap(radius);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('skill-field-areaRadius'));
      await reveal(field);
      await tester.enterText(field, '30');
      await tester.pumpAndSettle();
      // Rewind within the same card to change the boundary style.
      await tester.drag(find.byType(ListView).last, const Offset(0, 400));
      await tester.pumpAndSettle();
      final style = find.byKey(const ValueKey('skill-area-style'));
      await tester.ensureVisible(style);
      await tester.pumpAndSettle();
      tester.widget<DropdownButton<AreaGuideStyle>>(style).onChanged!(
        AreaGuideStyle.hidden,
      );
      await tester.pump();
      tester
          .widget<Slider>(find.byKey(const ValueKey('skill-area-opacity')))
          .onChanged!(.25);
      await tester.pump();
      final artwork = find.byKey(const ValueKey('skill-area-artwork'));
      await tester.ensureVisible(artwork);
      await tester.pumpAndSettle();
      await tester.tap(artwork);
      await tester.pumpAndSettle();
      expect(find.text('Area artwork'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-effect-ground')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final skill = saved!.library.builtIn(PowerUpKind.molotov, saved!.tuning);
      expect(skill.projectileOriginForward, 2);
      expect(skill.projectileOriginSide, -.25);
      expect(skill.areaRadiusRatio, .3);
      expect(skill.areaGuideStyle, AreaGuideStyle.hidden);
      expect(skill.areaGuideOpacity, .25);
      expect(tester.takeException(), isNull);
    },
  );
}
