import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({VoidCallback? onResult}) => MaterialApp(
    theme: AppTheme.build(AppPalettes.midnight),
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          await Navigator.of(context).push<SkillLibrary>(
            MaterialPageRoute(
              builder: (_) => const SkillManagementScreen(
                initial: SkillLibrary.defaults,
                tuning: PowerUpConfig.defaults,
              ),
            ),
          );
          onResult?.call();
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

      await tester.enterText(
        find.widgetWithText(TextField, 'Search skills'),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Boomerang'), findsNothing);
    },
  );

  testWidgets('admin can duplicate, edit and save a custom skill', (
    tester,
  ) async {
    SkillLibrary? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<SkillLibrary>(
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('visual-preview-item')), findsOneWidget);
    expect(find.byKey(const ValueKey('visual-preview-impact')), findsOneWidget);
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
    await tester.drag(find.byType(ListView).last, const Offset(0, 1400));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-arsenal')),
      '42',
    );
    await tester.tap(find.byKey(const ValueKey('skill-enabled')));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Heavy Pistol'), findsOneWidget);
    await tester.tap(find.text('Save for everyone'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.custom.single.name, 'Heavy Pistol');
    expect(result!.custom.single.arsenalDamage, 42);
    expect(result!.custom.single.enabled, isTrue);
    expect(
      result!.applyTo(PowerUpConfig.defaults).arenaDamage(PowerUpKind.pistol),
      42,
    );
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -220));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skill-trigger')), findsOneWidget);
    expect(find.byKey(const ValueKey('skill-effect-type')), findsOneWidget);
  });
}
