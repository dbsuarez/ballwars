import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';

// Image URLs point nowhere: previews fall back to plain white logo balls.
final _catalog =
    '''
{"version": 1, "groups": [
 {"id": "countries", "name": "Countries", "style": "flag", "balls": [
  {"id": "c0", "name": "Philippines", "image": "countries/ph.svg", "color": "#0038A8"},
  ${List.generate(24, (i) => '{"id": "x$i", "name": "Country $i", "image": "countries/x$i.svg", "color": "#123456"}').join(',')}]},
 {"id": "decision", "name": "Yes or No", "style": "flag", "balls": [
  {"id": "yes", "name": "YES", "image": "decision/yes.svg", "color": "#16A34A"},
  {"id": "no", "name": "NO", "image": "decision/no.svg", "color": "#DC2626"}]},
 {"id": "shoes", "name": "Apparel", "style": "logo", "balls": [
  {"id": "nike", "name": "Nike", "image": "shoes/nike.svg", "color": "#111111"},
  {"id": "adidas", "name": "Adidas", "image": "shoes/adidas.svg", "color": "#000000"},
  {"id": "puma", "name": "Puma", "image": "shoes/puma.svg", "color": "#242B2F"}]}
]}
''';

void main() {
  late MatchConfig? started;

  // Setup choices are remembered on the device: start each test fresh.
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  Future<void> pumpSetup(WidgetTester tester) async {
    started = null;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: MatchSetupScreen(
          packRepository: BallPackRepository(
            baseUri: Uri.parse('http://localhost:1/packs/'),
            fetch: (_) async => _catalog,
          ),
          onStartBattle: (config) => started = config,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickCategory(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'categories are sorted by name; the first opens by default and Start needs two balls',
    (tester) async {
      await pumpSetup(tester);
      expect(find.text('Nike'), findsOneWidget);

      await tester.tap(find.text('Nike'));
      await tester.pump();
      await tester.tap(find.text('Start'));
      expect(started, isNull);
    },
  );

  testWidgets(
    'switching categories clears the picks, so a match never mixes categories',
    (tester) async {
      await pumpSetup(tester);
      await tester.tap(find.text('Nike'));
      await pickCategory(tester, 'Countries');
      await tester.enterText(find.widgetWithText(TextField, 'Search'), 'phil');
      await tester.pumpAndSettle();
      expect(find.text('Country 3'), findsNothing);
      await tester.tap(find.text('Philippines'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      expect(started, isNull); // Nike was cleared: one ball only.

      await tester.enterText(
        find.widgetWithText(TextField, 'Search'),
        'country 3',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Country 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      expect(started!.contestants.map((b) => b.name), [
        'Philippines',
        'Country 3',
      ]);
    },
  );

  testWidgets('random matchup picks two balls from the current category', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));

    expect(started!.contestants.length, 2);
    expect(
      started!.contestants.every((b) => b.id.startsWith('pack:shoes/')),
      isTrue,
    );
  });

  testWidgets('small categories have no ball search; big ones do', (
    tester,
  ) async {
    await pumpSetup(tester);
    expect(find.widgetWithText(TextField, 'Search'), findsNothing);
    await pickCategory(tester, 'Countries');
    expect(find.widgetWithText(TextField, 'Search'), findsOneWidget);
  });

  testWidgets('rounds, speed and effects are passed to the match', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.tap(find.text('1 round'));
    await tester.tap(find.text('1×'));
    await tester.tap(find.text('On'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));

    expect(started!.winsNeeded, 2);
    expect(started!.speedMultiplier, 2);
    expect(started!.showEffects, isFalse);
  });

  testWidgets('rounds and speed are remembered for the next match setup', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.tap(find.text('1 round'));
    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await pumpSetup(tester);
    expect(find.text('First to 2'), findsOneWidget);
    expect(find.text('2×'), findsOneWidget);
  });

  testWidgets('Clear removes every picked ball', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Clear'), findsNothing);
    await tester.tap(find.text('Nike'));
    await tester.tap(find.text('Puma'));
    await tester.pump();
    expect(find.text('2/4'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('0/4'), findsOneWidget);
    expect(find.text('Clear'), findsNothing);
  });

  testWidgets('ball size is passed to the match and remembered', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Medium'));
    await tester.pump();
    expect(find.text('Large'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.ballSize, BallSize.large);

    await tester.pumpWidget(const SizedBox());
    await pumpSetup(tester);
    expect(find.text('Large'), findsOneWidget);
  });

  testWidgets('mode is passed to the match and remembered', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Threads'), findsOneWidget);
    await tester.tap(find.text('Arsenal'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.mode, MatchMode.arsenal);

    await tester.pumpWidget(const SizedBox());
    await pumpSetup(tester);
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.mode, MatchMode.arsenal);
  });

  testWidgets('ball look is passed to the match and remembered', (
    tester,
  ) async {
    await pumpSetup(tester);
    await tester.tap(find.byTooltip('Ball look: pictures'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.look, BallLook.faces);

    await tester.pumpWidget(const SizedBox());
    await pumpSetup(tester);
    expect(find.byTooltip('Ball look: faces'), findsOneWidget);
  });

  testWidgets('Yes or No lets the user ask a question', (tester) async {
    await pumpSetup(tester);
    expect(find.widgetWithText(TextField, 'Your question'), findsNothing);
    await pickCategory(tester, 'Yes or No');
    expect(find.widgetWithText(TextField, 'Your question'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Your question'),
      '  Will it rain?  ',
    );
    await tester.tap(find.text('YES'));
    await tester.tap(find.text('NO'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started!.question, 'Will it rain?');
  });

  testWidgets(
    'weapon cards toggle selections; select all works; Done needs at least one',
    (tester) async {
      await pumpSetup(tester);
      expect(find.textContaining('Weapons'), findsNothing);
      await tester.tap(find.text('Arsenal'));
      await tester.pump();
      expect(find.text('Pickups: All'), findsOneWidget);

      await tester.tap(find.text('Pickups: All'));
      await tester.pumpAndSettle();
      // Each one says what it does, with its damage.
      expect(
        find.text(powerUpDescription(PowerUpKind.pistol, arsenal: true)),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'one shot: ${PowerUpTuning.arenaDamage[PowerUpKind.pistol]!.round()} damage',
        ),
        findsOneWidget,
      );

      FilledButton done() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Done'),
      );
      // All off: nothing left, so Done waits for a pick.
      expect(find.text('Weapons, power-ups & traps'), findsOneWidget);
      expect(find.text('Weapons'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(SwitchListTile),
        ),
        findsNothing,
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
      final pistolDescription = powerUpDescription(
        PowerUpKind.pistol,
        arsenal: true,
      );
      final pistolCard = tester.widget<Card>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('selection-card-pistol')),
              matching: find.byType(Card),
            )
            .first,
      );
      final description = tester.widget<Text>(find.text(pistolDescription));
      final backgroundLuminance = pistolCard.color!.computeLuminance();
      final textLuminance = description.style!.color!.computeLuminance();
      final contrast =
          (textLuminance > backgroundLuminance
              ? textLuminance + 0.05
              : backgroundLuminance + 0.05) /
          (textLuminance > backgroundLuminance
              ? backgroundLuminance + 0.05
              : textLuminance + 0.05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pump();
      expect(done().onPressed, isNull);
      expect(find.text('Pick at least one.'), findsOneWidget);

      final first = find.byKey(
        ValueKey('selection-card-${PowerUpKind.values.first.name}'),
      );
      await tester.ensureVisible(first);
      await tester.pumpAndSettle();
      await tester.tap(first);
      await tester.pump();
      expect(done().onPressed, isNotNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      final selectableCount = PowerUpKind.values
          .where((kind) => !kind.isTrap)
          .length;
      expect(find.text('Pickups: 1 of $selectableCount'), findsOneWidget);

      // All on again.
      await tester.tap(find.text('Pickups: 1 of $selectableCount'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Select all'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Pickups: All'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pump();
      await tester.tap(find.text('Start'));
      expect(started!.powerUps, isNull);
    },
  );
}
