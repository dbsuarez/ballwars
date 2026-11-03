import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/settings/presentation/power_up_tuning_screen.dart';

void main() {
  Future<PowerUpConfig?> open(
    WidgetTester tester,
    PowerUpConfig initial,
    Future<void> Function() act,
  ) async {
    PowerUpConfig? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await Navigator.of(context).push<PowerUpConfig>(
                  MaterialPageRoute(
                    builder: (_) => PowerUpTuningScreen(initial: initial),
                  ),
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
    final tab =
        id.startsWith('dmg.') ||
            id == 'unarmedCollision' ||
            id == 'frozenDamageMultiplier' ||
            id == 'frozenCollisionDamage' ||
            id == 'bash' ||
            id == 'block' ||
            id == 'heal' ||
            id == 'maxLife'
        ? 'Arsenal'
        : id.startsWith('lines.') || id == 'keep' || id == 'appleLines'
        ? 'All-Out'
        : 'Common';
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
    final f = find.byKey(ValueKey('tuning-$id'));
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    return f;
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.text('Save');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
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

  testWidgets('trap deployment starts at one minute and can be changed', (
    tester,
  ) async {
    final result = await open(tester, PowerUpConfig.defaults, () async {
      final input = await field(tester, 'trapStart');
      expect(find.text('60'), findsWidgets);
      await tester.enterText(input, '90');
      await save(tester);
    });
    expect(result!.trapStartSteps, 90 * 60);
  });

  testWidgets('damage rows show icon, label and value inline', (tester) async {
    await open(tester, PowerUpConfig.defaults, () async {
      final value = await field(tester, 'dmg.pistol');
      final row = find.ancestor(of: value, matching: find.byType(Row)).first;
      expect(
        find.descendant(of: row, matching: find.text('Pistol')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.byType(PowerUpIcon)),
        findsOneWidget,
      );
      expect(
        tester
            .getCenter(
              find.descendant(of: row, matching: find.byType(PowerUpIcon)),
            )
            .dy,
        closeTo(tester.getCenter(value).dy, 20),
      );
    });
  });

  testWidgets('Restore defaults puts every number back', (tester) async {
    final changed = PowerUpConfig.defaults
        .withValue('dmg.pistol', 22)
        .withValue('ghost', 9);
    final result = await open(tester, changed, () async {
      await field(tester, 'dmg.pistol');
      expect(find.text('22'), findsOneWidget);
      final restore = find.text('Restore defaults');
      await tester.tap(restore);
      await tester.pump();
      await save(tester);
    });
    expect(result, PowerUpConfig.defaults);
  });

  testWidgets('trap master override has accessible tap help', (tester) async {
    await open(tester, PowerUpConfig.defaults, () async {
      await tester.tap(find.text('Common'));
      await tester.pumpAndSettle();
      final help = find.byKey(const ValueKey('trap-help-allTrapsDisabled'));
      await tester.ensureVisible(help);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(help).tooltip,
          contains('Disable all traps'));
      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.textContaining('Master override.'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Master override.'), findsNothing);
    });
  });

  testWidgets('trap switches save independent choices under master override',
      (tester) async {
    final result = await open(tester, PowerUpConfig.defaults, () async {
      await tester.tap(find.text('Common'));
      await tester.pumpAndSettle();
      Future<void> toggle(String id, bool value) async {
        final control = find.byKey(ValueKey('tuning-$id'));
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(control).value, isNot(value));
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(tester.widget<Switch>(control).value, value);
      }

      await toggle('arenaTrapsEnabled', false);
      await toggle('skillTrapsEnabled', false);
      await toggle('allTrapsDisabled', true);
      await save(tester);
    });
    expect(result, isNotNull);
    expect(result!.allTrapsDisabled, isTrue);
    expect(result.arenaTrapsEnabled, isFalse);
    expect(result.skillTrapsEnabled, isFalse);
    final restored = PowerUpConfig.fromJson(result.toJson())
        .withValue('allTrapsDisabled', 0);
    expect(restored.arenaTrapsEnabled, isFalse);
    expect(restored.skillTrapsEnabled, isFalse);
  });

  testWidgets('master override preserves independently enabled skill traps',
      (tester) async {
    final result = await open(tester, PowerUpConfig.defaults, () async {
      await tester.tap(find.text('Common'));
      await tester.pumpAndSettle();
      final arena = find.byKey(const ValueKey('tuning-arenaTrapsEnabled'));
      await tester.ensureVisible(arena);
      await tester.pumpAndSettle();
      await tester.tap(arena);
      await tester.pumpAndSettle();
      final master = find.byKey(const ValueKey('tuning-allTrapsDisabled'));
      await tester.ensureVisible(master);
      await tester.pumpAndSettle();
      await tester.tap(master);
      await tester.pumpAndSettle();
      await save(tester);
    });
    expect(result!.allTrapsDisabled, isTrue);
    final lifted = result.withValue('allTrapsDisabled', 0);
    expect(lifted.arenaTrapsEnabled, isFalse);
    expect(lifted.skillTrapsEnabled, isTrue);
  });

  testWidgets('an empty field blocks saving', (tester) async {
    await open(tester, PowerUpConfig.defaults, () async {
      await tester.enterText(await field(tester, 'dmg.pistol'), '');
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });
  });

  testWidgets(
    'on a wide screen it is as wide as Home and Settings (440), not the whole window',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(tester, PowerUpConfig.defaults, () async {
        expect(tester.getSize(find.byType(Scaffold).last).width, 440);
      });
    },
  );
}
