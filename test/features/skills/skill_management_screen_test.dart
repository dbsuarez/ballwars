import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-preview-item')), findsOneWidget);
    expect(find.byKey(const ValueKey('visual-preview-impact')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('skill-field-weaponGripInset')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-projectileSize')),
      '2',
    );
    await tester.pump();
    final projectilePreview = find.descendant(
      of: find.byKey(const ValueKey('visual-preview-impact')),
      matching: find.byType(PowerUpIcon),
    );
    expect(tester.widget<PowerUpIcon>(projectilePreview).size, 64);
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-field-arsenal')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-arsenal')),
      '42',
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-enabled')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Heavy Pistol'), findsOneWidget);
    await tester.tap(find.text('Save'));
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

    expect(
      find.byKey(const ValueKey('arena-trap-config-card')),
      findsOneWidget,
    );
    expect(find.textContaining('never collectibles'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arena-trap-config-card')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('arena-trap-arenaTrapInterval')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('arena-traps-enabled')));
    await tester.tap(find.byKey(const ValueKey('save-arena-trap-config')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Disabled'), findsOneWidget);
    expect(find.textContaining('every 20s'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
    await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('skill-item-rarity')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Epic').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-skill')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-trigger')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-trigger')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-bubble-type')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-bubble-type')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('callout-bubble-shout')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('callout-bubble-shout')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-yell')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.enterText(find.byKey(const ValueKey('skill-yell')), 'GO!');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('callout-style-preview')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    final shortBubble = tester.getSize(
      find.byKey(const ValueKey('callout-style-preview')),
    );
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-yell')),
      find.byType(ListView).last,
      const Offset(0, 300),
    );
    await tester.enterText(
      find.byKey(const ValueKey('skill-yell')),
      'UNLEASH THE GRAVITY STORM!',
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('callout-style-preview')),
      find.byType(ListView).last,
      const Offset(0, -300),
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-effect-type')),
      find.byType(ListView).last,
      const Offset(0, -300),
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-field-healing')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.byKey(const ValueKey('skill-field-healing')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('preview-skill')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
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
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('skill-targeting')),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
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
