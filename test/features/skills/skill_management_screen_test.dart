import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    await tester.enterText(
      find.byKey(const ValueKey('skill-field-arsenal')),
      '42',
    );
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
    expect(result!.custom.single.enabled, isFalse);
  });
}
