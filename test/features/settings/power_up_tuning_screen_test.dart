import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/settings/presentation/power_up_tuning_screen.dart';

void main() {
  Future<PowerUpConfig?> open(WidgetTester tester, PowerUpConfig initial, Future<void> Function() act) async {
    PowerUpConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await Navigator.of(context).push<PowerUpConfig>(
              MaterialPageRoute(builder: (_) => PowerUpTuningScreen(initial: initial)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    return result;
  }

  Future<Finder> field(WidgetTester tester, String id) async {
    final f = find.byKey(ValueKey('tuning-$id'));
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    return f;
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Save for everyone');
    await tester.scrollUntilVisible(button, 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('editing a number saves it', (tester) async {
    final result = await open(tester, PowerUpConfig.defaults, () async {
      await tester.enterText(await field(tester, 'dmg.pistol'), '22');
      await save(tester);
    });
    expect(result!.arenaDamage(PowerUpKind.pistol), 22);
    expect(result.overrides.length, 1);
  });

  testWidgets('Restore defaults puts every number back', (tester) async {
    final changed = PowerUpConfig.defaults.withValue('dmg.pistol', 22).withValue('ghost', 9);
    final result = await open(tester, changed, () async {
      await field(tester, 'dmg.pistol');
      expect(find.text('22'), findsOneWidget);
      final restore = find.text('Restore defaults');
      await tester.scrollUntilVisible(restore, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(restore);
      await tester.pump();
      await save(tester);
    });
    expect(result, PowerUpConfig.defaults);
  });

  testWidgets('an empty field blocks saving', (tester) async {
    await open(tester, PowerUpConfig.defaults, () async {
      await tester.enterText(await field(tester, 'dmg.pistol'), '');
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Save for everyone');
      await tester.scrollUntilVisible(button, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });
  });
}
