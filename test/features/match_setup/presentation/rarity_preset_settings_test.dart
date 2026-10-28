import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());
  MatchConfig? started;
  var generation = 0;
  Future<void> setup(
    WidgetTester tester, {
    MatchMode mode = MatchMode.arsenal,
    bool mayhem = false,
    PowerUpConfig tuning = PowerUpConfig.defaults,
    bool cards = true,
  }) async {
    started = null;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () =>
          DevicePrefs.write('match-settings-layout', cards ? 'cards' : 'list'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: AppSettingsScope(
          settings: ValueNotifier(AppSettings(powerUps: tuning)),
          child: MatchSetupScreen(
            key: ValueKey(generation++),
            initialMode: mode,
            initialMayhem: mayhem,
            packRepository: BallPackRepository(
              baseUri: Uri.parse('https://example.com/packs/'),
              fetch: (_) async => jsonEncode({
                'groups': [
                  {
                    'id': 'test',
                    'name': 'Test',
                    'style': 'logo',
                    'balls': [
                      for (var i = 0; i < 6; i++)
                        {
                          'id': 'b$i',
                          'name': 'Ball $i',
                          'color': '#2266AA',
                          'image': 'test/b$i.svg',
                        },
                    ],
                  },
                ],
              }),
            ),
            onStartBattle: (value) => started = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Edit match settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('rarity-preset')));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.byKey(const ValueKey('rarity-preset')));
    await tester.tap(find.byKey(const ValueKey('rarity-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String tier) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(ValueKey('rarity-weight-$tier')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;
  Future<void> close(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('match-settings-all-set')));
    await tester.pumpAndSettle();
  }

  for (final cards in [true, false]) {
    testWidgets(
      'Balanced is default and starts with frozen tuning in ${cards ? "cards" : "list"}',
      (tester) async {
        await setup(tester, cards: cards);
        await tester.tap(find.text('Random'));
        await tester.pumpAndSettle();
        await open(tester);
        expect(find.text('Balanced'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('rarity-odds-normal-nontrap')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('rarity-odds-normal-nontrap')),
              )
              .data,
          '40.0%',
        );
        await close(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Start'));
        expect(started, isNotNull);
        expect(
          [
            for (final tier in PowerUpRarity.values)
              started!.tuning.rarityWeight(tier),
          ],
          [40, 30, 20, 10],
        );
        expect(PowerUpConfig.defaults.rarityWeight(PowerUpRarity.normal), 50);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Custom seeds admin values and valid edits persist per mode', (
    tester,
  ) async {
    final admin = PowerUpConfig.defaults.withValue('rarity.normal', 80);
    await setup(tester, tuning: admin);
    await open(tester);
    await select(tester, 'Custom');
    expect(text(tester, 'normal'), '80.0');
    final normal = find.byKey(const ValueKey('rarity-weight-normal'));
    await tester.ensureVisible(normal);
    await tester.enterText(normal, '60');
    await tester.pumpAndSettle();
    await close(tester);
    await setup(tester, mode: MatchMode.allOut);
    await open(tester);
    expect(find.text('Balanced'), findsOneWidget);
    await select(tester, 'Competitive');
    await close(tester);
    await setup(tester, mayhem: true);
    await open(tester);
    expect(find.text('Balanced'), findsOneWidget);
    await select(tester, 'Casual');
    await close(tester);
    await setup(tester, tuning: admin.withValue('rarity.normal', 90));
    await open(tester);
    expect(find.text('Custom'), findsOneWidget);
    expect(text(tester, 'normal'), '60');
    expect(
      await tester.runAsync(
        () => DevicePrefs.read('match-allout-rarity-preset'),
      ),
      'competitive',
    );
    expect(
      await tester.runAsync(
        () => DevicePrefs.read('match-mayhem-rarity-preset'),
      ),
      'casual',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid custom weights block Start and Reset to Balanced repairs them',
    (tester) async {
      await setup(tester);
      await tester.tap(find.text('Random'));
      await tester.pumpAndSettle();
      await open(tester);
      await select(tester, 'Custom');
      for (final tier in PowerUpRarity.values) {
        final field = find.byKey(ValueKey('rarity-weight-${tier.name}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, '0');
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('rarity-error')), findsOneWidget);
      await close(tester);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNull,
      );
      expect(find.byKey(const ValueKey('match-rarity-error')), findsOneWidget);
      await open(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('rarity-reset-balanced')),
      );
      await tester.tap(find.byKey(const ValueKey('rarity-reset-balanced')));
      await tester.pumpAndSettle();
      expect(text(tester, 'normal'), '40');
      expect(find.byKey(const ValueKey('rarity-error')), findsNothing);
      await close(tester);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Start'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Threads hides pickup rarity controls', (tester) async {
    await setup(tester, mode: MatchMode.threads);
    await tester.tap(find.text('Edit match settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rarity-preset')), findsNothing);
  });
}
