import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/skills/presentation/skill_management_screen.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';

Future<void> library(
  WidgetTester tester, {
  Future<void> Function(SkillManagementResult)? save,
  SkillLibrary initial = SkillLibrary.defaults,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SkillManagementScreen(
        initial: initial,
        tuning: PowerUpConfig.defaults,
        onSave: save,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Search skills'),
    'Pistol',
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(ListTile, 'Pistol'));
  await tester.pumpAndSettle();
}

Future<Finder> damage(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('skill-editor-tab-mechanics'));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
  final field = find.byKey(const ValueKey('skill-field-arsenal'));
  if (field.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      field,
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }
  return field;
}

Future<void> close(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close).last);
  await tester.pumpAndSettle();
}

Future<void> restore(WidgetTester tester) async {
  final card = find.widgetWithText(ListTile, 'Pistol');
  await tester.tap(
    find.descendant(of: card, matching: find.byType(PopupMenuButton<String>)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Restore original settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('confirm-restore-built-in')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('clean close and a reverted numeric edit do not ask to discard', (
    tester,
  ) async {
    await library(tester, save: (_) async {});
    await open(tester);
    await close(tester);
    expect(find.text('Unsaved skill changes'), findsNothing);
    await open(tester);
    final field = await damage(tester);
    final initial = tester.widget<TextField>(field).controller!.text;
    await tester.enterText(field, '7');
    await tester.pumpAndSettle();
    await tester.enterText(field, initial);
    await tester.pumpAndSettle();
    await close(tester);
    expect(find.text('Unsaved skill changes'), findsNothing);
    expect(
      find.byKey(const ValueKey('skill-editor-tab-identity')),
      findsNothing,
    );
  });
  testWidgets(
    'close and Android back offer keep editing or discard without losing the draft',
    (tester) async {
      await library(tester, save: (_) async {});
      await open(tester);
      var field = await damage(tester);
      await tester.enterText(field, '7');
      await tester.pumpAndSettle();
      await close(tester);
      expect(find.text('Unsaved skill changes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skill-exit-keep')));
      await tester.pumpAndSettle();
      field = await damage(tester);
      expect(tester.widget<TextField>(field).controller!.text, '7');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved skill changes'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skill-exit-discard')));
      await tester.pumpAndSettle();
      await open(tester);
      field = await damage(tester);
      expect(
        double.parse(tester.widget<TextField>(field).controller!.text),
        PowerUpConfig.defaults.arenaDamage(PowerUpKind.pistol),
      );
    },
  );
  testWidgets('failed exit save keeps the draft and retry saves then closes', (
    tester,
  ) async {
    var attempts = 0;
    SkillManagementResult? saved;
    await library(
      tester,
      save: (result) async {
        attempts++;
        if (attempts == 1) throw StateError('Offline');
        saved = result;
      },
    );
    await open(tester);
    var field = await damage(tester);
    await tester.enterText(field, '7');
    await tester.pumpAndSettle();
    await close(tester);
    await tester.tap(find.byKey(const ValueKey('skill-exit-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Skill could not be saved'), findsOneWidget);
    field = await damage(tester);
    expect(tester.widget<TextField>(field).controller!.text, '7');
    await close(tester);
    await tester.tap(find.byKey(const ValueKey('skill-exit-save')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      saved!.library.builtIn(PowerUpKind.pistol, saved!.tuning).arsenalDamage,
      7,
    );
    expect(
      find.byKey(const ValueKey('skill-editor-tab-identity')),
      findsNothing,
    );
    await open(tester);
    field = await damage(tester);
    expect(double.parse(tester.widget<TextField>(field).controller!.text), 7);
    await close(tester);
    expect(find.text('Unsaved skill changes'), findsNothing);
  });
  testWidgets(
    'direct save establishes a clean baseline and invalid drafts cannot save on exit',
    (tester) async {
      await library(tester, save: (_) async {});
      await open(tester);
      var field = await damage(tester);
      await tester.enterText(field, '7');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pumpAndSettle();
      await close(tester);
      expect(find.text('Unsaved skill changes'), findsNothing);
      await open(tester);
      field = await damage(tester);
      await tester.enterText(field, 'oops');
      await tester.pumpAndSettle();
      await close(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('skill-exit-save')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('skill-exit-discard')));
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'library restore failure is visible, preserves override, and retries successfully',
    (tester) async {
      var attempts = 0;
      SkillManagementResult? saved;
      final builtin = SkillLibrary.defaults
          .builtIn(PowerUpKind.pistol, PowerUpConfig.defaults)
          .copyWith(arsenalDamage: 7);
      await library(
        tester,
        initial: SkillLibrary.defaults.withDefinition(
          builtin,
          PowerUpConfig.defaults,
        ),
        save: (result) async {
          attempts++;
          if (attempts == 1) throw StateError('Offline');
          saved = result;
        },
      );
      await restore(tester);
      expect(
        find.textContaining('Restore failed. Your current settings were kept.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-restore-built-in')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(saved!.library.hasBuiltInOverride(builtin.id), isFalse);
      await open(tester);
      final field = await damage(tester);
      expect(
        double.parse(tester.widget<TextField>(field).controller!.text),
        PowerUpConfig.defaults.arenaDamage(PowerUpKind.pistol),
      );
    },
  );
  testWidgets(
    'edits made while a save is pending are still dirty after that save succeeds',
    (tester) async {
      final gate = Completer<void>();
      await library(tester, save: (_) => gate.future);
      await open(tester);
      final field = await damage(tester);
      await tester.enterText(field, '7');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-skill')));
      await tester.pump();
      await tester.enterText(field, '6');
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      await close(tester);
      expect(find.text('Unsaved skill changes'), findsOneWidget);
    },
  );
}
