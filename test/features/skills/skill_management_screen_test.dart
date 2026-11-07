import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:ballwars/features/skills/presentation/skill_demo_dialog.dart';

Future<void> _revealEditor(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  Future<bool> scan() async {
    final list = find.byType(ListView).last;
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 50; i++) {
      if (target.evaluate().isNotEmpty) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        if (target.hitTestable().evaluate().isNotEmpty) return true;
      }
      if (position.pixels >= position.maxScrollExtent) break;
      position.jumpTo(
        (position.pixels + 180).clamp(0.0, position.maxScrollExtent),
      );
      await tester.pumpAndSettle();
    }
    return false;
  }

  for (final label in [
    'Identity',
    'Mechanics',
    'Timing & Delivery',
    'Visuals & Sprites',
    'Audio & Callouts',
    'Test & Preview',
  ]) {
    final sectionTab = find.widgetWithText(Tab, label);
    if (sectionTab.evaluate().isEmpty) continue;
    await tester.ensureVisible(sectionTab);
    await tester.tap(sectionTab);
    await tester.pumpAndSettle();
    if (label == 'Visuals & Sprites') {
      for (final sub in [
        'Artwork',
        'Held & pickup',
        'Projectiles',
        'Effects',
        'Area',
        'Shells',
        'Legacy',
      ]) {
        final tab = find.widgetWithText(Tab, sub);
        if (tab.evaluate().isEmpty) continue;
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        if (await scan()) {
          return;
        }
      }
    } else if (await scan()) {
      return;
    }
  }
  fail('Editor control not found: $target');
}

/// Selects a Unified Skill Library filter without relying on removed legacy tabs.
Future<void> _setSkillLibraryFilter(
  WidgetTester tester,
  String filter,
  String choice,
) async {
  final libraryTab = find.widgetWithText(Tab, 'Skill Library');
  if (libraryTab.evaluate().isNotEmpty) {
    await tester.tap(libraryTab);
    await tester.pumpAndSettle();
  }
  final dropdown = find.byKey(ValueKey('skill-filter-$filter'));
  expect(dropdown, findsOneWidget);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

/// Scrolls the Global tab until [target] is built and on screen.
Future<void> _revealGlobal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('skill-global-settings')),
        matching: find.byType(Scrollable),
      )
      .first;
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(target, 120, scrollable: scrollable);
  await tester.pumpAndSettle();
}

/// Records the straight lines drawn (the preview's hand crosshair); every
/// other call is ignored.
class _LineRecorder implements Canvas {
  final List<(Offset, Offset)> lines = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) => lines.add((p1, p2));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _openTrapSettings(
  WidgetTester tester,
  void Function(SkillManagementResult) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(AppPalettes.midnight),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final result = await Navigator.of(context)
                .push<SkillManagementResult>(
                  MaterialPageRoute(
                    builder: (_) => SkillManagementScreen(
                      initial: SkillLibrary.defaults,
                      tuning: PowerUpConfig.defaults,
                    ),
                  ),
                );
            if (result != null) onResult(result);
          },
          child: const Text('Open Skill Management'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open Skill Management'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('library save failure retains route and allows retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
          onSave: (_) async {
            if (++attempts == 1) throw StateError('offline');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Library'));
    await tester.pumpAndSettle();
    expect(find.byType(SkillManagementScreen), findsOneWidget);
    expect(find.textContaining('Your draft is still here'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Skill library saved.'), findsOneWidget);
  });

  testWidgets('unified trap master override provides accessible tap help', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
    await tester.pumpAndSettle();
    final help = find.byKey(const ValueKey('trap-help-allTrapsDisabled'));
    await _revealGlobal(tester, help);
    expect(
      tester.widget<IconButton>(help).tooltip,
      contains('Disable all traps'),
    );
    await tester.tap(help);
    await tester.pumpAndSettle();
    expect(find.textContaining('Master override.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Master override.'), findsNothing);
  });

  testWidgets(
    'unified trap switches persist independent choices under master override',
    (tester) async {
      SkillManagementResult? saved;
      await _openTrapSettings(tester, (result) => saved = result);
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      Future<void> toggle(String id, bool value) async {
        final control = find.byKey(ValueKey('global-$id'));
        await _revealGlobal(tester, control);
        expect(tester.widget<SwitchListTile>(control).value, isNot(value));
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(control).value, value);
      }

      await toggle('arenaTrapsEnabled', false);
      await toggle('skillTrapsEnabled', false);
      await toggle('allTrapsDisabled', true);
      await tester.tap(find.text('Save Library'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      final result = saved!.tuning;
      expect(result.allTrapsDisabled, isTrue);
      expect(result.arenaTrapsEnabled, isFalse);
      expect(result.skillTrapsEnabled, isFalse);
      final restored = PowerUpConfig.fromJson(
        result.toJson(),
      ).withValue('allTrapsDisabled', 0);
      expect(restored.arenaTrapsEnabled, isFalse);
      expect(restored.skillTrapsEnabled, isFalse);
    },
  );

  testWidgets(
    'unified master override preserves independently enabled skill traps',
    (tester) async {
      SkillManagementResult? saved;
      await _openTrapSettings(tester, (result) => saved = result);
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      for (final id in ['arenaTrapsEnabled', 'allTrapsDisabled']) {
        final control = find.byKey(ValueKey('global-$id'));
        await _revealGlobal(tester, control);
        await tester.tap(control);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save Library'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      final result = saved!.tuning;
      expect(result.allTrapsDisabled, isTrue);
      final lifted = result.withValue('allTrapsDisabled', 0);
      expect(lifted.arenaTrapsEnabled, isFalse);
      expect(lifted.skillTrapsEnabled, isTrue);
    },
  );

  testWidgets(
    'legacy artwork has pill tags and editing preserves shared bindings',
    (tester) async {
      var library = SkillLibrary.defaults.withEffect(
        const EffectDefinition(
          id: 'effect.hit',
          name: 'Shared hit',
          spriteId: 'custom.sheet.hit',
        ),
      );
      library = library.withDefinition(
        library
            .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
            .copyWith(
              visualBindings: const {
                SkillVisualRole.impact: SkillVisualBinding(
                  effectId: 'effect.hit',
                ),
              },
            ),
        PowerUpConfig.defaults,
      );
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: library,
            tuning: PowerUpConfig.defaults,
            onSave: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      // Legacy sprite selectors were retired; shared event bindings remain editable.
      expect(find.text('Casting artwork'), findsNothing);
      final damage = find.byKey(const ValueKey('skill-field-arsenal'));
      await _revealEditor(tester, damage);
      await tester.enterText(damage, '7');
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(saved!.library.effects['effect.hit']!.name, 'Shared hit');
      final skill = saved!.library.builtIn(PowerUpKind.pistol, saved!.tuning);
      expect(
        skill.visualBindings[SkillVisualRole.impact]!.effectId,
        'effect.hit',
      );
      expect(skill.arsenalDamage, 7);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'phone editor toolbar opens Skill Demo with unsaved values and returns without saving',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (_) async {
              saves++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      final damage = find.byKey(const ValueKey('skill-field-arsenal'));
      await _revealEditor(tester, damage);
      await tester.enterText(damage, '7');
      await tester.pump();
      for (final key in [
        'preview-skill',
        'demo-skill',
        'test-skill-live',
        'preview-skill-finisher',
      ]) {
        expect(find.byKey(ValueKey(key)).hitTestable(), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('demo-skill')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SkillDemoDialog>(find.byType(SkillDemoDialog))
            .skill
            .arsenalDamage,
        7,
      );
      expect(
        find.byKey(const ValueKey('use-demo-skill')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('close-skill-demo')));
      await tester.pumpAndSettle();
      await _revealEditor(tester, damage);
      expect(tester.widget<TextField>(damage).controller!.text, '7');
      expect(saves, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'retired casting and impact selectors are absent; legacy data remains readable',
    (tester) async {
      final legacy = SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(
            castingSpriteId: 'old-cast.png',
            impactSpriteId: 'old-hit.png',
          );
      final migrated = SkillLibrary.defaults.migrateLegacyArtwork(legacy);
      expect(
        migrated.library
            .resolveVisual(migrated.skill, SkillVisualRole.casting)
            ?.spriteId,
        'old-cast.png',
      );
      expect(
        migrated.library
            .resolveVisual(migrated.skill, SkillVisualRole.impact)
            ?.spriteId,
        'old-hit.png',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SkillManagementScreen(
            initial: migrated.library.withDefinition(
              migrated.skill,
              PowerUpConfig.defaults,
            ),
            tuning: PowerUpConfig.defaults,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      expect(find.text('Casting artwork'), findsNothing);
      expect(find.text('Impact / effect artwork'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Global: Default effect visuals comes back with Save Library', (
    tester,
  ) async {
    SkillManagementResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context)
                .push<SkillManagementResult>(
                  MaterialPageRoute(
                    builder: (_) => const SkillManagementScreen(
                      initial: SkillLibrary.defaults,
                      tuning: PowerUpConfig.defaults,
                    ),
                  ),
                ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
    await tester.pumpAndSettle();
    await _revealGlobal(
      tester,
      find.byKey(const ValueKey('global-effect-visuals')),
    );
    await tester.tap(find.byKey(const ValueKey('global-effect-visuals')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(EffectRenderMode.vector.label).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Library'));
    await tester.pumpAndSettle();
    expect(result!.effectVisuals, EffectRenderMode.vector);
  });

  testWidgets(
    'Global: switching off "Let each skill set its own" disables the callout field in every skill',
    (tester) async {
      const tuning = PowerUpConfig.defaults;
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
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      await _revealGlobal(
        tester,
        find.byKey(const ValueKey('global-callout-seconds')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('global-callout-seconds')),
        '2.5',
      );
      await tester.tap(find.byKey(const ValueKey('skills-set-callout')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Every skill uses this duration'),
        findsOneWidget,
      );

      await _setSkillLibraryFilter(tester, 'category', 'Weapons');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('skill-field-bubbleDuration'));
      await _revealEditor(tester, field);
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(
        find.textContaining('Using the global callout duration (2.5 s)'),
        findsOneWidget,
      );
      expect(saved, isNull);
    },
  );

  testWidgets(
    'Global: Apply to all skills asks first, then sets each skill and saves with Save Library',
    (tester) async {
      const tuning = PowerUpConfig.defaults;
      final custom = SkillLibrary.defaults.create('Zap', PowerUpKind.pistol);
      final initial = SkillLibrary.defaults.withDefinition(custom, tuning);
      final count = initial.all(tuning).length;
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await Navigator.of(context)
                  .push<SkillManagementResult>(
                    MaterialPageRoute(
                      builder: (_) => SkillManagementScreen(
                        initial: initial,
                        tuning: tuning,
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('global-effect-display-scale'));
      await _revealGlobal(tester, field);
      await tester.enterText(field, '1.5');
      await tester.pumpAndSettle();
      final apply = find.byKey(
        const ValueKey('apply-all-effect-display-scale'),
      );
      await _revealGlobal(tester, apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      expect(
        find.text(
          "Set 1.5x on all $count skills? This changes each skill's own value."
          ' Built-in skills you have not edited yet become individually edited skills, so Edit power-up numbers (Legacy) will no longer change them.',
        ),
        findsOneWidget,
      );
      // Cancel changes nothing.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply-all-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Set 1.5x on all $count skills.'),
        findsOneWidget,
      );

      // A value out of range can't be applied.
      final shake = find.byKey(const ValueKey('global-screen-shake'));
      await _revealGlobal(tester, shake);
      await tester.enterText(shake, '5');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('apply-all-screen-shake')),
            )
            .enabled,
        isFalse,
      );

      await tester.tap(find.text('Save Library'));
      await tester.pumpAndSettle();
      final library = saved!.library;
      for (final skill in library.all(tuning)) {
        expect(skill.effectDisplayScale, 1.5, reason: skill.id);
        expect(skill.screenShake, isNot(5), reason: skill.id);
      }
      expect(library.skillsSetEffectDisplayScale, isTrue);
      expect(library.custom.single.name, 'Zap');
    },
  );

  testWidgets(
    'Global: each of the five Apply to all skills buttons changes its field',
    (tester) async {
      const tuning = PowerUpConfig.defaults;
      final initial = SkillLibrary.defaults.withDefinition(
        SkillLibrary.defaults.create('Zap', PowerUpKind.pistol),
        tuning,
      );
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => saved = await Navigator.of(context)
                  .push<SkillManagementResult>(
                    MaterialPageRoute(
                      builder: (_) => SkillManagementScreen(
                        initial: initial,
                        tuning: tuning,
                      ),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      for (final (field, value) in [
        ('callout-seconds', '3.5'),
        ('screen-shake', '0.7'),
        ('weapon-display-scale', '1.75'),
        ('pickup-display-scale', '2.25'),
        ('effect-display-scale', '0.5'),
      ]) {
        final input = find.byKey(ValueKey('global-$field'));
        await _revealGlobal(tester, input);
        await tester.enterText(input, value);
        await tester.pumpAndSettle();
        final apply = find.byKey(ValueKey('apply-all-$field'));
        await _revealGlobal(tester, apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('apply-all-confirm')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Save Library'));
      await tester.pumpAndSettle();
      final skills = saved!.library.all(tuning);
      expect(skills, hasLength(initial.all(tuning).length));
      for (final skill in skills) {
        expect(skill.bubbleDurationSeconds, 3.5, reason: skill.id);
        expect(skill.screenShake, 0.7, reason: skill.id);
        expect(skill.weaponDisplayScale, 1.75, reason: skill.id);
        expect(skill.pickupDisplayScale, 2.25, reason: skill.id);
        expect(skill.effectDisplayScale, 0.5, reason: skill.id);
      }
    },
  );

  testWidgets('Global: the five cards fit a 360 px phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: const SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
    await tester.pumpAndSettle();
    for (final field in [
      'callout-seconds',
      'screen-shake',
      'weapon-display-scale',
      'pickup-display-scale',
      'effect-display-scale',
    ]) {
      await _revealGlobal(tester, find.byKey(ValueKey('apply-all-$field')));
      expect(find.byKey(ValueKey('global-$field')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: field);
    }
  });

  testWidgets(
    'Global: the sprite size switches disable the matching fields in every skill',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Global Defaults'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('global-weapon-display-scale'));
      await _revealGlobal(tester, field);
      await tester.enterText(field, '2');
      final toggle = find.byKey(
        const ValueKey('skills-set-weapon-display-scale'),
      );
      await _revealGlobal(tester, toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Every weapon in hand is drawn at this size'),
        findsOneWidget,
      );
      await _setSkillLibraryFilter(tester, 'category', 'Weapons');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      final scale = find.byKey(
        const ValueKey('skill-field-weaponDisplayScale'),
      );
      await _revealEditor(tester, scale);
      expect(tester.widget<TextField>(scale).enabled, isFalse);
      expect(
        find.textContaining('Using the global equipped artwork size (2x)'),
        findsOneWidget,
      );
      final pickup = find.byKey(
        const ValueKey('skill-field-pickupDisplayScale'),
      );
      await _revealEditor(tester, pickup);
      expect(tester.widget<TextField>(pickup).enabled, isTrue);
    },
  );

  testWidgets(
    'Combine: pick a look and a fired skill; a broken reference blocks Save and says why',
    (tester) async {
      const tuning = PowerUpConfig.defaults;
      final boom = SkillLibrary.defaults
          .create('Boom-merang', PowerUpKind.boomerang)
          .copyWith(returnsToOrigin: true);
      final combo = SkillLibrary.defaults
          .create('Knife Volley', PowerUpKind.knife)
          .copyWith(payloadSkillId: 'custom.gone', projectileCount: 3);
      final library = SkillLibrary.defaults
          .withDefinition(boom, tuning)
          .withDefinition(combo, tuning);
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: library,
            tuning: tuning,
            onSave: (result) async => saved = result,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _setSkillLibraryFilter(tester, 'source', 'Custom');
      await tester.pumpAndSettle();
      // The filtered list may place Knife Volley below the visible viewport.
      // Tapping an off-screen ListTile silently misses and leaves the editor
      // unopened. Bring the tile into view and verify the dialog is mounted.
      final knifeVolley = find.widgetWithText(ListTile, 'Knife Volley');
      if (knifeVolley.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          knifeVolley,
          100,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(knifeVolley, findsOneWidget);
      await tester.ensureVisible(knifeVolley);
      await tester.pumpAndSettle();
      expect(knifeVolley.hitTestable(), findsOneWidget);
      await tester.tap(knifeVolley);
      await tester.pumpAndSettle();
      final identityTab = find.byKey(
        const ValueKey('skill-editor-tab-identity'),
      );
      expect(identityTab, findsOneWidget);
      // Identity is the default editor tab; no controller manipulation needed.
      final problem = find.byKey(const ValueKey('skill-fires-problem'));
      await _revealEditor(tester, problem);
      expect(tester.widget<Text>(problem).data, contains('no longer exists'));
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('save-skill')))
            .onPressed,
        isNull,
      );

      await _revealEditor(tester, find.byKey(const ValueKey('skill-fires')));
      await tester.tap(find.byKey(const ValueKey('skill-fires')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boom-merang').last);
      await tester.pumpAndSettle();
      expect(problem, findsNothing);
      expect(
        find.textContaining('come from the skill it fires'),
        findsOneWidget,
      );

      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-looks-like')),
      );
      await tester.tap(find.byKey(const ValueKey('skill-looks-like')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sword').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final edited = saved!.library.byId(combo.id, saved!.tuning)!;
      expect(edited.payloadSkillId, boom.id);
      expect(edited.artworkKind, PowerUpKind.sword);
      expect(
        saved!.library.byId(boom.id, saved!.tuning)!.toJson(),
        library.byId(boom.id, tuning)!.toJson(),
      );
    },
  );

  testWidgets(
    'editor saves directly, reports failures, and keeps edits for retry',
    (tester) async {
      SkillManagementResult? saved;
      var failSave = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (result) async {
              if (failSave) throw StateError('offline');
              saved = result;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-field-arsenal')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('skill-field-arsenal')),
        '17',
      );
      await tester.pump();
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-sprite-tint')),
      );
      await tester.tap(find.byKey(const ValueKey('skill-sprite-tint')));
      await tester.pumpAndSettle();
      final goldSwatch = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFFFFD700),
      );
      await tester.tap(goldSwatch);
      await tester.tap(find.text('Use color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Skill could not be saved:'), findsOneWidget);
      expect(find.byKey(const ValueKey('save-skill')), findsOneWidget);
      failSave = false;
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(
        saved!.library.builtIn(PowerUpKind.pistol, saved!.tuning).arsenalDamage,
        17,
      );
      expect(find.text('Skill saved.'), findsOneWidget);
      expect(
        saved!.library.builtIn(PowerUpKind.pistol, saved!.tuning).spriteTint,
        0xFFFFD700,
      );
      expect(find.byKey(const ValueKey('save-skill')), findsOneWidget);
    },
  );

  Widget app({ValueChanged<SkillManagementResult?>? onResult}) => MaterialApp(
    theme: AppTheme.build(AppPalettes.midnight),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final result = await Navigator.of(context)
              .push<SkillManagementResult>(
                MaterialPageRoute(
                  builder: (_) => const SkillManagementScreen(
                    initial: SkillLibrary.defaults,
                    tuning: PowerUpConfig.defaults,
                  ),
                ),
              );
          onResult?.call(result);
        },
        child: const Text('open'),
      ),
    ),
  );

  testWidgets(
    'phone editor keeps fixed labels and aligned previews without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-new-skill')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Skill name'),
        'Phone skill',
      );
      await tester.tap(find.text('Build skill'));
      await tester.pumpAndSettle();
      for (final key in [
        'skill-category',
        'skill-trigger',
        'skill-targeting',
        'skill-delivery',
        'skill-field-repeatCount',
        'skill-field-count',
        'skill-field-arsenal',
        'visual-preview-item',
        'skill-field-weaponDisplayScale',
        'skill-field-projectileSize',
        'skill-yell',
        'preview-skill-sound',
      ]) {
        await _revealEditor(tester, find.byKey(ValueKey(key)));
        expect(tester.takeException(), isNull, reason: key);
        for (final action in [
          'preview-skill',
          'test-skill-live',
          'preview-skill-finisher',
        ]) {
          expect(
            find.byKey(ValueKey(action)).hitTestable(),
            findsOneWidget,
            reason: '$action stays visible while editing $key',
          );
        }
      }
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('visual-preview-item')),
      );
      final item = tester.getRect(
        find.byKey(const ValueKey('visual-preview-item')),
      );
      final projectile = tester.getRect(
        find.byKey(const ValueKey('visual-preview-impact')),
      );
      expect(item.size, projectile.size);
      expect(item.top, projectile.top);
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-field-repeatCount')),
      );
      final repeatField = find.byKey(const ValueKey('skill-field-repeatCount'));
      await tester.enterText(repeatField, '1');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('skill-increase-repeatCount')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('skill-decrease-repeatCount')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('skill-increase-repeatCount')),
      );
      await tester.pump();
      expect(tester.widget<TextField>(repeatField).controller!.text, '2');
      await tester.enterText(repeatField, '10');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('skill-decrease-repeatCount')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('skill-increase-repeatCount')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('skill-decrease-repeatCount')),
      );
      await tester.pump();
      expect(tester.widget<TextField>(repeatField).controller!.text, '9');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unified category filter persists while searching and clears independently',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _setSkillLibraryFilter(tester, 'category', 'Power-ups');
      expect(find.widgetWithText(ListTile, 'Apple'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Boomerang'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Apple',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Apple'), findsOneWidget);
      final chip = find.ancestor(
        of: find.text('Search: Apple'),
        matching: find.byType(InputChip),
      );
      tester.widget<InputChip>(chip).onDeleted!();
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Apple'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Boomerang'), findsNothing);
    },
  );

  testWidgets('skill names use normal rare epic and special tier colors', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Future<Color?> colorFor(String query, String id) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        query,
      );
      await tester.pumpAndSettle();
      return tester
          .widget<Text>(find.byKey(ValueKey('skill-name-$id')))
          .style
          ?.color;
    }

    expect(await colorFor('Pistol', 'builtin.pistol'), Colors.white);
    expect(
      await colorFor('Shotgun', 'builtin.shotgun'),
      PowerUpRarity.rare.color,
    );
    expect(
      await colorFor('Rocket Launcher', 'builtin.rocketLauncher'),
      PowerUpRarity.epic.color,
    );
    expect(
      await colorFor('Spike Wall', 'builtin.spikeWall'),
      const Color(0xFFFFD54F),
    );
  });

  testWidgets('all built-in numeric edits survive Done and library Save', (
    tester,
  ) async {
    SkillManagementResult? result;
    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Boomerang',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Boomerang'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Mechanics'));
    await tester.pumpAndSettle();
    final editor = find.byType(ListView).last;
    for (
      var i = 0;
      i < 8 &&
          find.byKey(const ValueKey('skill-field-arsenal')).evaluate().isEmpty;
      i++
    ) {
      await tester.drag(editor, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-arsenal')),
      '7',
    );
    for (
      var i = 0;
      i < 8 &&
          find
              .byKey(const ValueKey('skill-field-knockback'))
              .evaluate()
              .isEmpty;
      i++
    ) {
      await tester.drag(editor, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-knockback')),
      '20',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('skill-field-knockback')),
          )
          .controller!
          .text,
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();

    final saved = result!.library.builtIn(
      PowerUpKind.boomerang,
      PowerUpConfig.defaults,
    );
    expect(saved.arsenalDamage, 7);
    expect(saved.knockback, 20);
    final reopened = SkillLibrary.fromJson(
      result!.library.toJson(),
    ).builtIn(PowerUpKind.boomerang, PowerUpConfig.defaults);
    expect(reopened.arsenalDamage, 7);
    expect(reopened.knockback, 20);
  });

  Future<bool> showsMeleeReach(
    WidgetTester tester,
    String skill, {
    ValueChanged<SkillManagementResult?>? onResult,
  }) async {
    await tester.pumpWidget(app(onResult: onResult ?? (_) {}));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      skill,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, skill).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Mechanics'));
    await tester.pumpAndSettle();
    final editor = find.byType(ListView).last;
    const key = ValueKey('skill-field-meleeReach');
    for (var i = 0; i < 10 && find.byKey(key).evaluate().isEmpty; i++) {
      await tester.drag(editor, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    return find.byKey(key).evaluate().isNotEmpty;
  }

  testWidgets('a gun has no melee reach field', (tester) async {
    expect(await showsMeleeReach(tester, 'Pistol'), isFalse);
  });

  testWidgets('the orbiting flail explains its own reach', (tester) async {
    expect(await showsMeleeReach(tester, 'Orbiting Flail'), isTrue);
    expect(
      find.text(
        'The flail already reaches about 1.7 ball radii; higher values extend it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('melee reach is edited on contact weapons and saved', (
    tester,
  ) async {
    SkillManagementResult? result;
    expect(
      await showsMeleeReach(
        tester,
        'Knife',
        onResult: (value) => result = value,
      ),
      isTrue,
    );
    expect(find.text('Melee reach (ball radii)'), findsOneWidget);
    expect(find.text('ball radii'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-meleeReach')),
      '1.5',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();
    final saved = result!.library.builtIn(
      PowerUpKind.knife,
      PowerUpConfig.defaults,
    );
    expect(saved.meleeReach, 1.5);
  });

  testWidgets('grip preview edits forward/back, sideways and rotation live', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SkillManagementResult? result;
    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pistol').first);
    await tester.pumpAndSettle();

    final button = find.byKey(const ValueKey('skill-grip-preview'));
    await _revealEditor(tester, button);
    for (final (key, label, suffix) in const [
      ('weaponGripInset', 'Grip forward/back', 'ball radius'),
      ('weaponGripSide', 'Grip sideways', 'ball radius'),
      ('weaponGripRotation', 'Grip rotation', 'degrees'),
    ]) {
      await _revealEditor(tester, find.byKey(ValueKey('skill-field-$key')));
      expect(find.text('$label ($suffix)'), findsOneWidget);
    }
    await _revealEditor(tester, button);

    String field(String key) => tester
        .widget<TextField>(find.byKey(ValueKey('skill-field-$key')))
        .controller!
        .text;
    Future<void> slide(String key, double value) async {
      tester
          .widget<Slider>(find.byKey(ValueKey('grip-preview-$key')))
          .onChanged!(value);
      await tester.pump();
    }

    // Cancel discards.
    await tester.tap(button);
    await tester.pumpAndSettle();
    final dialog = find.byKey(const ValueKey('grip-preview-dialog'));
    expect(dialog, findsOneWidget);
    expect(tester.getSize(dialog).width, lessThanOrEqualTo(440));
    expect(find.byKey(const ValueKey('grip-preview-right')), findsOneWidget);
    expect(find.byKey(const ValueKey('grip-preview-left')), findsOneWidget);
    await slide('side', 0.5);
    final cancel = find.byKey(const ValueKey('grip-preview-cancel'));
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(double.parse(field('weaponGripSide')), 0);

    // Done writes back.
    await tester.tap(button);
    await tester.pumpAndSettle();
    await slide('inset', 0.4);
    await slide('side', -0.5);
    await slide('rotation', 30);
    expect(tester.takeException(), isNull);
    // A crosshair marks the hand in both views (red lines), at the standard
    // grip point: it stays put however the sliders move.
    void expectMarker() {
      for (final (key, right) in const [('right', true), ('left', false)]) {
        final finder = find.byKey(ValueKey('grip-preview-$key'));
        final s = tester.getSize(finder).shortestSide;
        final r = s * 0.16;
        final sign = right ? 1 : -1;
        // Pistol: 1.2r ahead - 0.45r back, 0.3r down (mirrored sideways).
        final hand = Offset(
          tester.getSize(finder).width * (right ? 0.36 : 0.64) +
              sign * 0.75 * r,
          tester.getSize(finder).height / 2 + 0.3 * r,
        );
        final arm = r * 0.3;
        final rec = _LineRecorder();
        final box = tester.renderObject<RenderCustomPaint>(finder);
        box.painter!.paint(rec, box.size);
        expect(rec.lines, hasLength(2));
        for (final (i, want) in [
          (hand - Offset(arm, 0), hand + Offset(arm, 0)),
          (hand - Offset(0, arm), hand + Offset(0, arm)),
        ].indexed) {
          expect(rec.lines[i].$1.dx, closeTo(want.$1.dx, 1e-6));
          expect(rec.lines[i].$1.dy, closeTo(want.$1.dy, 1e-6));
          expect(rec.lines[i].$2.dx, closeTo(want.$2.dx, 1e-6));
          expect(rec.lines[i].$2.dy, closeTo(want.$2.dy, 1e-6));
        }
      }
    }

    expectMarker();
    await slide('inset', -1);
    await slide('side', 1);
    await slide('rotation', -90);
    expectMarker();
    await slide('inset', 0.4);
    await slide('side', -0.5);
    await slide('rotation', 30);
    // Forward/back can go negative (push the weapon out).
    await slide('inset', -0.5);
    await slide('inset', 0.4);
    // The expanded grip dialog is taller than the test viewport. Scroll the
    // Facing control into the visible area before opening its popup menu.
    final facing = find.byKey(const ValueKey('grip-preview-facing'));
    await tester.ensureVisible(facing);
    await tester.pumpAndSettle();
    await tester.tap(facing);
    await tester.pumpAndSettle();
    final upright = find.text('Stay upright').last;
    expect(upright, findsOneWidget);
    await tester.tap(upright);
    await tester.pumpAndSettle();
    final done = find.byKey(const ValueKey('grip-preview-done'));
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    final savedGripFields = <String, String>{};
    for (final key in [
      'weaponGripInset',
      'weaponGripSide',
      'weaponGripRotation',
    ]) {
      await _revealEditor(tester, find.byKey(ValueKey('skill-field-$key')));
      savedGripFields[key] = field(key);
    }
    expect(double.parse(savedGripFields['weaponGripInset']!), 0.4);
    expect(double.parse(savedGripFields['weaponGripSide']!), -0.5);
    expect(double.parse(savedGripFields['weaponGripRotation']!), 30);
    expect(savedGripFields['weaponGripInset'], '0.40');
    expect(savedGripFields['weaponGripRotation'], '30');

    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();
    final saved = result!.library.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    expect(saved.weaponGripInset, 0.4);
    expect(saved.heldFacing, SkillHeldFacing.upright);
    expect(saved.weaponGripSide, -0.5);
    expect(saved.weaponGripRotation, 30);
  });

  testWidgets('gun skills edit their shell in Appearance, restore and save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SkillManagementResult? result;
    Future<void> openSkill(String name) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        name,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, name).first);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await openSkill('Gatling');

    final enabled = find.byKey(const ValueKey('skill-shell-enabled'));
    await _revealEditor(tester, enabled);
    await _revealEditor(
      tester,
      find.textContaining('Spent casings this gun drops'),
    );
    await _revealEditor(tester, enabled);
    expect(find.text('Default (On)'), findsOneWidget);
    expect(find.text('Brass shell (default)'), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-shell-preview')), findsOneWidget);

    Future<void> pickShells(String label) async {
      await _revealEditor(tester, enabled);
      await tester.tap(enabled);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    final size = find.byKey(const ValueKey('skill-field-shellSize'));
    final count = find.byKey(const ValueKey('skill-field-shellCount'));
    final rest = find.byKey(const ValueKey('skill-shell-random-rest'));
    Future<void> editAll() async {
      await pickShells('Off');
      await _revealEditor(tester, size);
      await tester.enterText(size, '10');
      await tester.pump();
      await _revealEditor(tester, count);
      await tester.enterText(count, '3');
      await tester.pump();
      await _revealEditor(tester, rest);
      await tester.tap(rest);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(rest).value, isFalse);
    }

    // Restore defaults puts every shell setting back.
    await editAll();
    final restore = find.byKey(const ValueKey('restore-skill-defaults'));
    await _revealEditor(tester, restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    await _revealEditor(tester, enabled);
    expect(find.text('Default (On)'), findsOneWidget);
    await _revealEditor(tester, size);
    expect(tester.widget<TextField>(size).controller!.text, '1.0');
    await _revealEditor(tester, count);
    expect(tester.widget<TextField>(count).controller!.text, '1');
    await _revealEditor(tester, rest);
    expect(tester.widget<SwitchListTile>(rest).value, isTrue);

    await editAll();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();
    final saved = result!.library.builtIn(
      PowerUpKind.gatling,
      PowerUpConfig.defaults,
    );
    expect(saved.shellEnabled, isFalse);
    expect(saved.shellSize, 10);
    expect(saved.shellCount, 3);
    expect(saved.shellRandomRest, isFalse);
    expect(saved.shellSprite, isNull);
  });

  testWidgets('attack duration dropdown fits a 360 px phone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Use the same reachable Shotgun row as the existing phone-layout
    // regression below. On a 360 px phone the filtered Sword tile may be
    // behind the bottom navigation bar, so tapping it never opens an editor.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Shotgun',
    );
    await tester.pumpAndSettle();
    final skill = find.widgetWithText(ListTile, 'Shotgun');
    expect(skill.hitTestable(), findsOneWidget);
    await tester.tap(skill);
    await tester.pumpAndSettle();
    final duration = find.byKey(const ValueKey('skill-held-attack-duration'));
    await _revealEditor(tester, duration);
    expect(duration.hitTestable(), findsOneWidget);
    final attackVfx = find.byKey(const ValueKey('skill-held-attack-vfx'));
    await _revealEditor(tester, attackVfx);
    expect(attackVfx, findsOneWidget);
    expect(find.text('Held Attack VFX'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phone subtab drafts, decimal steppers and linked shell counts survive save and reopen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SkillManagementResult? saved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (result) async => saved = result,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Shotgun',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Shotgun'));
      await tester.pumpAndSettle();
      final shots = find.byKey(const ValueKey('skill-field-count'));
      final shells = find.byKey(const ValueKey('skill-field-shellCount'));
      final scale = find.byKey(const ValueKey('skill-field-shellSize'));
      await _revealEditor(tester, shots);
      await tester.enterText(shots, '3');
      await tester.pumpAndSettle();
      await _revealEditor(tester, shells);
      expect(tester.widget<TextField>(shells).controller!.text, '3');
      await tester.tap(find.byKey(const ValueKey('skill-increase-shellCount')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(shells).controller!.text, '4');
      await _revealEditor(tester, scale);
      await tester.enterText(scale, '1.2');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('skill-increase-shellSize')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(scale).controller!.text, '1.3');
      // Leaving Appearance and returning retains the active subtab and draft.
      await tester.ensureVisible(find.widgetWithText(Tab, 'Identity'));
      await tester.tap(find.widgetWithText(Tab, 'Identity'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Visuals & Sprites'));
      await tester.tap(find.widgetWithText(Tab, 'Visuals & Sprites'));
      await tester.pumpAndSettle();
      expect(shells.hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(scale).controller!.text, '1.3');
      await _revealEditor(tester, shots);
      expect(tester.widget<TextField>(shots).controller!.text, '4');
      await tester.enterText(shots, '100');
      await tester.pumpAndSettle();
      await _revealEditor(tester, shells);
      expect(tester.widget<TextField>(shells).controller!.text, '100');
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const ValueKey('skill-increase-shellCount')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(shells, '6');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      final skill = saved!.library.builtIn(PowerUpKind.shotgun, saved!.tuning);
      expect(skill.projectileCount, 6);
      expect(skill.shellCount, 6);
      expect(skill.shellSize, 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Shotgun'));
      await tester.pumpAndSettle();
      await _revealEditor(tester, shots);
      expect(tester.widget<TextField>(shots).controller!.text, '6');
      await _revealEditor(tester, shells);
      expect(tester.widget<TextField>(shells).controller!.text, '6');
      await _revealEditor(tester, scale);
      expect(tester.widget<TextField>(scale).controller!.text, '1.3');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a composed skill that is not aimed has no shell settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var library = SkillLibrary.defaults;
    final bump = library
        .create('Bump Shot', PowerUpKind.pistol)
        .copyWith(
          trigger: SkillTrigger.collision,
          delivery: SkillDelivery.instant,
        );
    library = library.withDefinition(bump, PowerUpConfig.defaults);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<SkillManagementResult>(
              MaterialPageRoute(
                builder: (_) => SkillManagementScreen(
                  initial: library,
                  tuning: PowerUpConfig.defaults,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _setSkillLibraryFilter(tester, 'source', 'Custom');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Bump Shot').first);
    await tester.pumpAndSettle();
    // Its grip controls are on Appearance, so the tab is the right one.
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-field-pickupDisplayScale')),
    );
    final list = find.byType(ListView).last;
    for (var i = 0; i < 20; i++) {
      expect(find.byKey(const ValueKey('skill-shell-enabled')), findsNothing);
      await tester.drag(list, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('non-gun skills have no shell settings', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Knife',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Knife').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Visuals & Sprites'));
    await tester.pumpAndSettle();
    final list = find.byType(ListView).last;
    for (var i = 0; i < 20; i++) {
      expect(find.byKey(const ValueKey('skill-shell-enabled')), findsNothing);
      await tester.drag(list, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('versioned JSON can be exported and imported as a draft', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('export-skill-library')));
    await tester.pumpAndSettle();
    expect(find.text('Export skill library'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('copy-skill-library-json')),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('import-skill-library')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('skill-library-json-input')),
      '{"version":1,"overrides":{},"custom":[]}',
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-skill-library-import')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Imported as a draft. Save to publish it.'),
      findsOneWidget,
    );
  });

  testWidgets('unchanged prefilled description retains generated behavior', (
    tester,
  ) async {
    SkillManagementResult? result;
    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pistol').first);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('skill-description'));
    await _revealEditor(tester, field);
    expect(
      tester.widget<TextField>(field).controller!.text,
      powerUpDescription(PowerUpKind.pistol, arsenal: true),
    );
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Library'));
    await tester.pumpAndSettle();
    expect(
      result!.library.builtIn(PowerUpKind.pistol, result!.tuning).description,
      isEmpty,
    );
  });

  testWidgets('custom and built-in skills take a description', (tester) async {
    final library = SkillLibrary.defaults.withDefinition(
      SkillLibrary.defaults
          .create('Story Pistol', PowerUpKind.pistol)
          .copyWith(enabled: true),
      PowerUpConfig.defaults,
    );
    SkillManagementResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<SkillManagementResult>(
                MaterialPageRoute(
                  builder: (_) => SkillManagementScreen(
                    initial: library,
                    tuning: PowerUpConfig.defaults,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A built-in skill takes a description too, shown in the list.
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pistol').first);
    await tester.pumpAndSettle();
    final builtInField = find.byKey(const ValueKey('skill-description'));
    await _revealEditor(tester, builtInField);
    expect(tester.widget<TextField>(builtInField).maxLength, 160);
    expect(
      tester.widget<TextField>(builtInField).controller!.text,
      powerUpDescription(PowerUpKind.pistol, arsenal: true),
    );
    expect(find.text(_builtInSaveNote), findsOneWidget);
    await tester.enterText(builtInField, ' Bang\n bang. ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bang bang.'), findsOneWidget);

    // Restore defaults clears it (closed without saving).
    await tester.tap(find.widgetWithText(ListTile, 'Pistol').first);
    await tester.pumpAndSettle();
    await _revealEditor(tester, builtInField);
    expect(
      tester.widget<TextField>(builtInField).controller!.text,
      'Bang bang.',
    );
    final restore = find.byKey(const ValueKey('restore-skill-defaults'));
    await _revealEditor(tester, restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    await _revealEditor(tester, builtInField);
    expect(
      tester.widget<TextField>(builtInField).controller!.text,
      powerUpDescription(PowerUpKind.pistol, arsenal: true),
    );
    Navigator.of(tester.element(find.text('Edit Pistol'))).pop();
    await tester.pumpAndSettle();

    await _setSkillLibraryFilter(tester, 'source', 'Custom');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Independent skill using Pistol artwork'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Story Pistol').first);
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('skill-description'));
    await _revealEditor(tester, field);
    expect(tester.widget<TextField>(field).maxLength, 160);
    expect(find.text(_builtInSaveNote), findsNothing);
    await tester.enterText(field, '  Fires\ntwo  bullets.  ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fires two bullets.'), findsOneWidget);
    expect(
      find.textContaining('Independent skill using Pistol artwork'),
      findsNothing,
    );
    await tester.tap(find.text('Save Library'));
    await tester.pumpAndSettle();
    expect(result!.library.custom.single.description, 'Fires two bullets.');
    expect(
      result!.library
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .description,
      'Bang bang.',
    );
  });

  testWidgets('admin can duplicate, edit and save a custom skill', (
    tester,
  ) async {
    SkillManagementResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<SkillManagementResult>(
                MaterialPageRoute(
                  builder: (_) => const SkillManagementScreen(
                    initial: SkillLibrary.defaults,
                    tuning: PowerUpConfig.defaults,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Skill Management'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'New skill name'),
      'Heavy Pistol',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Duplicate'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Heavy Pistol'), findsOneWidget);
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('visual-preview-item')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-preview-item')), findsOneWidget);
    expect(find.byKey(const ValueKey('visual-preview-impact')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('visual-preview-item'))),
      tester.getSize(find.byKey(const ValueKey('visual-preview-impact'))),
    );
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-field-projectileSize')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-projectileSize')),
      '2',
    );
    await tester.pump();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('visual-preview-impact')),
    );
    final projectilePreview = find.descendant(
      of: find.byKey(const ValueKey('visual-preview-impact')),
      matching: find.byType(PowerUpIcon),
    );
    expect(tester.widget<PowerUpIcon>(projectilePreview).size, 64);
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('preview-skill-sound')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('preview-skill-sound')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('skill-settings-info')));
    await tester.pumpAndSettle();
    expect(find.text('Skill settings guide'), findsOneWidget);
    expect(find.text('Audio & Callouts'), findsWidgets);
    // Guide deep links must use the editor controller and preserve its draft.
    await tester.tap(find.byKey(const ValueKey('skill-guide-jump-1')));
    await tester.pumpAndSettle();
    expect(find.text('Skill settings guide'), findsNothing);
    expect(find.widgetWithText(Tab, 'Mechanics'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skill-settings-info')));
    await tester.pumpAndSettle();
    expect(find.text('Skill settings guide'), findsOneWidget);
    expect(find.text('Mechanics'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-field-arsenal')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-arsenal')),
      '42',
    );
    await _revealEditor(tester, find.byKey(const ValueKey('skill-enabled')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await _setSkillLibraryFilter(tester, 'source', 'Custom');
    await tester.pumpAndSettle();
    expect(find.text('Heavy Pistol'), findsOneWidget);
    await tester.tap(find.text('Save Library'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.library.custom.single.name, 'Heavy Pistol');
    expect(result!.library.custom.single.arsenalDamage, 42);
    expect(result!.library.custom.single.enabled, isTrue);
    expect(result!.library.custom.single.arsenalDamage, 42);
  });

  testWidgets('arena trap tuning is available in unified Traps category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SkillManagementResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<SkillManagementResult>(
                MaterialPageRoute(
                  builder: (_) => const SkillManagementScreen(
                    initial: SkillLibrary.defaults,
                    tuning: PowerUpConfig.defaults,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _setSkillLibraryFilter(tester, 'category', 'Traps');
    await tester.pumpAndSettle();

    for (final name in [
      'Gravity Well',
      'Quicksand',
      'Vine Snare',
      'Laser Gate',
    ]) {
      expect(find.byKey(ValueKey('arena-trap-card-$name')), findsOneWidget);
    }
    expect(find.textContaining('Arena • Enabled'), findsNWidgets(4));
    await tester.tap(find.byKey(const ValueKey('arena-trap-card-Quicksand')));
    await tester.pumpAndSettle();
    expect(find.text('Quicksand settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('arena-trap-quicksandDamage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('arena-trap-laserGateDamage')),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('arena-trap-arenaTrapInterval')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('arena-traps-enabled')));
    await tester.tap(find.byKey(const ValueKey('save-arena-trap-config')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Arena • Disabled'), findsNWidgets(4));
    expect(find.textContaining('every 20s'), findsNWidgets(4));

    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.tuning.arenaTrapsEnabled, isFalse);
    expect(result!.tuning.value('arenaTrapInterval'), 20);
  });

  testWidgets('item rarity is edited directly with its skill', (tester) async {
    SkillManagementResult? result;
    await tester.pumpWidget(app(onResult: (value) => result = value));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'Pistol',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
    await tester.pumpAndSettle();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-item-rarity')),
    );
    await tester.tap(find.byKey(const ValueKey('skill-item-rarity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Epic').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.tuning.rarityOf(PowerUpKind.pistol), PowerUpRarity.epic);
  });

  testWidgets(
    'a custom skill keeps its own tier apart from its base built-in, both ways',
    (tester) async {
      final kutsilyo = SkillLibrary.defaults.create(
        'Kutsilyo',
        PowerUpKind.knife,
      );
      final library = SkillLibrary.defaults.withDefinition(
        kutsilyo,
        PowerUpConfig.defaults,
      );
      SkillManagementResult? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.of(context)
                    .push<SkillManagementResult>(
                      MaterialPageRoute(
                        builder: (_) => SkillManagementScreen(
                          initial: library,
                          tuning: PowerUpConfig.defaults,
                        ),
                      ),
                    );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Kutsilyo to Special.
      await _setSkillLibraryFilter(tester, 'source', 'Custom');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Kutsilyo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Kutsilyo'));
      await tester.pumpAndSettle();
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-item-rarity')),
      );
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-item-rarity')),
      );
      await tester.tap(find.byKey(const ValueKey('skill-item-rarity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Special').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(ValueKey('skill-name-${kutsilyo.id}')))
            .style
            ?.color,
        PowerUpRarity.special.color,
      );

      // The built-in Knife to Rare.
      await _setSkillLibraryFilter(tester, 'source', 'Built-in');
      await tester.pumpAndSettle();
      await _setSkillLibraryFilter(tester, 'category', 'Weapons');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Knife',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Knife'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Knife'));
      await tester.pumpAndSettle();
      await _revealEditor(
        tester,
        find.byKey(const ValueKey('skill-item-rarity')),
      );
      expect(
        tester
            .widget<DropdownButtonFormField<PowerUpRarity>>(
              find.byKey(const ValueKey('skill-item-rarity')),
            )
            .initialValue,
        PowerUpRarity.normal,
      );
      await tester.tap(find.byKey(const ValueKey('skill-item-rarity')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rare').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
      await tester.pumpAndSettle();

      final saved = result!;
      expect(saved.tuning.rarityOf(PowerUpKind.knife), PowerUpRarity.rare);
      final custom = saved.library.custom.single;
      expect(custom.rarity, PowerUpRarity.special);
      expect(custom.calloutStyle, SkillCalloutStyle.special);
      expect(
        SkillLibrary.rarityOf(custom, saved.tuning),
        PowerUpRarity.special,
      );
    },
  );

  testWidgets('admin can create a composed skill from scratch', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-new-skill')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Skill name'),
      'Gravity Burst',
    );
    await tester.tap(find.text('Build skill'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Gravity Burst'), findsOneWidget);
    await _revealEditor(tester, find.byKey(const ValueKey('skill-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-trigger')), findsOneWidget);
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-bubble-type')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-bubble-type')), findsOneWidget);
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('callout-bubble-shout')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('callout-bubble-shout')), findsOneWidget);
    await _revealEditor(tester, find.byKey(const ValueKey('skill-yell')));
    await tester.enterText(find.byKey(const ValueKey('skill-yell')), 'GO!');
    await tester.pumpAndSettle();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('callout-style-preview')),
    );
    final shortBubble = tester.getSize(
      find.byKey(const ValueKey('callout-style-preview')),
    );
    await _revealEditor(tester, find.byKey(const ValueKey('skill-yell')));
    await tester.enterText(
      find.byKey(const ValueKey('skill-yell')),
      'UNLEASH THE GRAVITY STORM!',
    );
    await tester.pumpAndSettle();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('callout-style-preview')),
    );
    final longBubble = tester.getSize(
      find.byKey(const ValueKey('callout-style-preview')),
    );
    expect(longBubble.width, greaterThan(shortBubble.width));
    await tester.tap(find.byKey(const ValueKey('skill-bubble-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thought - quiet or psychic').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('callout-bubble-thought')),
      findsOneWidget,
    );
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-effect-type')),
    );
    expect(find.byKey(const ValueKey('skill-effect-type')), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-weapon-healing')), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-field-healing')), findsNothing);
    tester
        .widget<SwitchListTile>(
          find.byKey(const ValueKey('skill-weapon-healing')),
        )
        .onChanged!(true);
    await tester.pumpAndSettle();
    await _revealEditor(
      tester,
      find.byKey(const ValueKey('skill-field-healing')),
    );
    expect(find.byKey(const ValueKey('skill-field-healing')), findsOneWidget);
    await _revealEditor(tester, find.byKey(const ValueKey('preview-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preview-skill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('replay-skill-preview')), findsOneWidget);
    expect(find.text('Gravity Burst'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-skill-live')), findsOneWidget);
  });

  testWidgets('invalid composed combinations are explained and cannot save', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('create-new-skill')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Skill name'),
      'Invalid Apple Shot',
    );
    await tester.tap(find.text('Build skill'));
    await tester.pumpAndSettle();
    await _revealEditor(tester, find.byKey(const ValueKey('skill-targeting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skill-targeting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('self').last);
    await tester.pumpAndSettle();

    final save = tester.widget<TextButton>(
      find.byKey(const ValueKey('save-skill')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets(
    'unified library reports zero matches and preserves empty state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (value) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'unlikely-no-matching-skill-987654',
      );
      await tester.pumpAndSettle();
      expect(find.text('0 matching items'), findsOneWidget);
      expect(
        find.text('No matching skills. Adjust the filters or search.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search appears as removable active filter and clears independently',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'pistol',
      );
      await tester.pumpAndSettle();
      expect(find.text('Search: pistol'), findsOneWidget);
      final activeSearch = find.ancestor(
        of: find.text('Search: pistol'),
        matching: find.byType(InputChip),
      );
      expect(activeSearch, findsOneWidget);
      tester.widget<InputChip>(activeSearch).onDeleted!();
      await tester.pumpAndSettle();
      expect(find.text('Search: pistol'), findsNothing);
      expect(find.byKey(const ValueKey('active-skill-filters')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clear filters is disabled until a filter or query is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SkillManagementScreen(
          initial: SkillLibrary.defaults,
          tuning: PowerUpConfig.defaults,
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final clear = find.byKey(const ValueKey('clear-skill-filters'));
    expect(tester.widget<TextButton>(clear).onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search skills'),
      'epic',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(clear).onPressed, isNotNull);
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(clear).onPressed, isNull);
    expect(find.text('Search: epic'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'preview editor links return to the selected configuration section',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: SkillManagementScreen(
            initial: SkillLibrary.defaults,
            tuning: PowerUpConfig.defaults,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
      await tester.pumpAndSettle();
      final previewTab = find.byKey(const ValueKey('skill-editor-tab-preview'));
      await tester.ensureVisible(previewTab);
      await tester.tap(previewTab);
      await tester.pumpAndSettle();
      final editMechanics = find.widgetWithText(ActionChip, 'Edit Mechanics');
      expect(editMechanics, findsOneWidget);
      await tester.tap(editMechanics);
      await tester.pumpAndSettle();
      expect(find.text('Mechanics'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

const _builtInSaveNote =
    'Saving a built-in skill stores its current numbers; Edit power-up numbers (Legacy) will no longer change it.';
