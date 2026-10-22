import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
 {"id": "shoes", "name": "Apparel", "style": "logo", "balls": [
  {"id": "nike", "name": "Nike", "image": "shoes/nike.svg", "color": "#111111"},
  {"id": "adidas", "name": "Adidas", "image": "shoes/adidas.svg", "color": "#000000"},
  {"id": "puma", "name": "Puma", "image": "shoes/puma.svg", "color": "#242B2F"}]}
]}
''';

void main() {
  late MatchConfig? started;

  Future<void> pumpSetup(WidgetTester tester) async {
    started = null;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: MatchSetupScreen(
          packRepository: BallPackRepository(baseUri: Uri.parse('http://localhost:1/packs/'), fetch: (_) async => _catalog),
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

  testWidgets('categories are sorted by name; the first opens by default and Start needs two balls', (tester) async {
    await pumpSetup(tester);
    expect(find.text('Nike'), findsOneWidget);

    await tester.tap(find.text('Nike'));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(started, isNull);
  });

  testWidgets('the category dropdown switches categories and picks can be mixed', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Nike'));
    await pickCategory(tester, 'Countries');
    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'phil');
    await tester.pumpAndSettle();
    expect(find.text('Country 3'), findsNothing);
    await tester.tap(find.text('Philippines'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));

    expect(started!.contestants.map((b) => b.name), ['Nike', 'Philippines']);
    expect(started!.contestants.first.id, 'pack:shoes/nike');
  });

  testWidgets('random matchup picks two balls from the current category', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.byIcon(Icons.shuffle));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));

    expect(started!.contestants.length, 2);
    expect(started!.contestants.every((b) => b.id.startsWith('pack:shoes/')), isTrue);
  });

  testWidgets('small categories have no ball search; big ones do', (tester) async {
    await pumpSetup(tester);
    expect(find.widgetWithText(TextField, 'Search'), findsNothing);
    await pickCategory(tester, 'Countries');
    expect(find.widgetWithText(TextField, 'Search'), findsOneWidget);
  });

  testWidgets('rounds, speed and effects are passed to the match', (tester) async {
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
}
