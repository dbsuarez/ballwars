import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/match_setup/data/loadout_preset_store.dart';
import 'package:ballwars/features/match_setup/domain/loadout_preset.dart';
import 'package:ballwars/features/match_setup/presentation/loadout_presets_dialog.dart';

class _FailingStore extends LoadoutPresetStore {
  @override
  Future<void> write(List<LoadoutPreset> presets) async =>
      throw StateError('disk full');
}

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  Future<void> open(
    WidgetTester tester, {
    LoadoutPresetStore? store,
    ValueChanged<LoadoutPreset?>? onResult,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => onResult?.call(
                await showDialog<LoadoutPreset>(
                  context: context,
                  builder: (_) => LoadoutPresetsDialog(
                    store: store,
                    currentKinds: const {PowerUpKind.knife},
                    currentCustomIds: const {'custom.kutsilyo'},
                    availableCustomNames: const {'custom.kutsilyo': 'Kutsilyo'},
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('phone saves, renames and deletes a named selection', (
    tester,
  ) async {
    await open(tester, onResult: (_) {});
    await tester.tap(find.byKey(const ValueKey('save-loadout-preset')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'My weapons');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.text('My weapons'), findsOneWidget);
    await tester.tap(find.byTooltip('About My weapons'));
    await tester.pumpAndSettle();
    expect(find.text('Kutsilyo'), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('My weapons options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Blades');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect((await LoadoutPresetStore().read()).single.name, 'Blades');
    await tester.tap(find.byTooltip('Blades options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await LoadoutPresetStore().read(), isEmpty);
    expect(find.textContaining('No saved presets yet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applying built-in returns explicit pickup pool', (tester) async {
    LoadoutPreset? result;
    await open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Military'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-loadout-presets')));
    await tester.pumpAndSettle();
    expect(result!.kinds, LoadoutPreset.military);
    expect(result!.customIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mix across tabs, inspect without selecting, save mix and apply',
    (tester) async {
      await LoadoutPresetStore().write([
        LoadoutPreset(
          id: 'extra',
          name: 'Extra',
          kinds: {PowerUpKind.knife, PowerUpKind.boomerang},
          customIds: {'custom.kutsilyo'},
        ),
      ]);
      LoadoutPreset? result;
      await open(tester, onResult: (value) => result = value);
      await tester.tap(find.byTooltip('About Military'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Rocket Launcher'), findsOneWidget);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('apply-loadout-presets')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Military'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extra'));
      await tester.pumpAndSettle();
      expect(find.text('2 presets / 11 unique pickups'), findsOneWidget);
      await tester.tap(find.text('Extra'));
      await tester.pumpAndSettle();
      expect(find.text('1 presets / 9 unique pickups'), findsOneWidget);
      await tester.tap(find.text('Extra'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-loadout-preset')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Mixed');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      final saved = (await LoadoutPresetStore().read()).last;
      expect(saved.name, 'Mixed');
      expect(saved.kinds, {...LoadoutPreset.military, PowerUpKind.boomerang});
      expect(saved.customIds, {'custom.kutsilyo'});
      await tester.tap(find.byKey(const ValueKey('apply-loadout-presets')));
      await tester.pumpAndSettle();
      expect(result!.kinds, saved.kinds);
      expect(result!.customIds, saved.customIds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable custom skills are explained and duplicate names rejected',
    (tester) async {
      await LoadoutPresetStore().write([
        LoadoutPreset(
          id: 'old',
          name: 'Blades',
          kinds: {PowerUpKind.knife},
          customIds: {'deleted.custom'},
        ),
      ]);
      await open(tester, onResult: (_) {});
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1 custom skills unavailable'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('save-loadout-preset')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'blades');
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(
        find.text('A saved preset already uses this name.'),
        findsOneWidget,
      );
      expect(await LoadoutPresetStore().read(), hasLength(1));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed saves stay visible and do not add a phantom preset', (
    tester,
  ) async {
    await open(tester, store: _FailingStore(), onResult: (_) {});
    await tester.tap(find.byKey(const ValueKey('save-loadout-preset')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Failure');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save presets'), findsOneWidget);
    expect(await LoadoutPresetStore().read(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
