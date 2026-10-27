import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _revealEditor(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  for (final label in [
    'Identity',
    'Damage & Timing',
    'Appearance',
    'Callouts & Sounds',
  ]) {
    await tester.ensureVisible(find.widgetWithText(Tab, label));
    await tester.tap(find.widgetWithText(Tab, label));
    await tester.pumpAndSettle();
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
        return;
      }
      if (position.pixels >= position.maxScrollExtent) break;
      await tester.drag(list, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
  }
  fail('Editor control not found: $target');
}

void main() {
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
    await tester.tap(find.widgetWithText(Tab, 'Global'));
    await tester.pumpAndSettle();
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
      await tester.tap(find.widgetWithText(Tab, 'Global'));
      await tester.pumpAndSettle();
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

      await tester.tap(find.widgetWithText(Tab, 'Weapons'));
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
      await tester.tap(find.widgetWithText(Tab, 'Custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Knife Volley'));
      await tester.pumpAndSettle();

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
    'built-in categories use tabs and search temporarily ignores them',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('built-in-skill-tabs')), findsOneWidget);
      expect(find.text('Boomerang'), findsOneWidget);
      expect(find.text('Apple'), findsNothing);

      await tester.tap(find.text('Power-ups'));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Boomerang'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        'Pistol',
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Pistol'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('clear-skill-search')));
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Boomerang'), findsNothing);
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

    await tester.tap(find.widgetWithText(Tab, 'Damage & Timing'));
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
    await tester.tap(find.widgetWithText(Tab, 'Damage & Timing'));
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
    expect(find.text('Melee reach'), findsOneWidget);
    expect(find.text('ball radii'), findsOneWidget);
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
    for (final (key, label) in const [
      ('weaponGripInset', 'Grip forward/back'),
      ('weaponGripSide', 'Grip sideways'),
      ('weaponGripRotation', 'Grip rotation'),
    ]) {
      await _revealEditor(tester, find.byKey(ValueKey('skill-field-$key')));
      expect(find.text(label), findsOneWidget);
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
    await tester.tap(find.byKey(const ValueKey('grip-preview-cancel')));
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
    await tester.tap(find.byKey(const ValueKey('grip-preview-done')));
    await tester.pumpAndSettle();
    expect(double.parse(field('weaponGripInset')), 0.4);
    expect(double.parse(field('weaponGripSide')), -0.5);
    expect(double.parse(field('weaponGripRotation')), 30);
    expect(field('weaponGripInset'), '0.40');
    expect(field('weaponGripRotation'), '30');

    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Library'));
    await tester.pumpAndSettle();
    final saved = result!.library.builtIn(
      PowerUpKind.pistol,
      PowerUpConfig.defaults,
    );
    expect(saved.weaponGripInset, 0.4);
    expect(saved.weaponGripSide, -0.5);
    expect(saved.weaponGripRotation, 30);
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
    await tester.tap(find.text('Custom'));
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

  testWidgets('arena trap tuning is available in the built-in Traps tab', (
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
    await tester.tap(find.text('Traps'));
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
}
