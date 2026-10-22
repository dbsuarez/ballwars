import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';

// Image URLs point nowhere: previews fall back to plain white logo balls.
final _catalog = '''
{"version": 1, "groups": [
 {"id": "shoes", "name": "Shoes", "style": "logo", "balls": [
  {"id": "nike", "name": "Nike", "image": "shoes/nike.svg", "color": "#111111"},
  {"id": "adidas", "name": "Adidas", "image": "shoes/adidas.svg", "color": "#000000"},
  {"id": "puma", "name": "Puma", "image": "shoes/puma.svg", "color": "#242B2F"}]},
 {"id": "countries", "name": "Countries", "style": "flag", "balls": [
  ${'{"id": "c0", "name": "Philippines", "image": "countries/ph.svg", "color": "#0038A8"},'}
  ${List.generate(24, (i) => '{"id": "x$i", "name": "Country $i", "image": "countries/x$i.svg", "color": "#123456"}').join(',')}]}
]}
''';

void main() {
  late MatchConfig? started;

  Future<void> pumpSetup(WidgetTester tester) async {
    started = null;
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MatchSetupScreen(
        repository: LocalBallRepository(),
        packRepository: BallPackRepository(
          baseUri: Uri.parse('http://localhost:1/packs/'),
          fetch: (_) async => _catalog,
        ),
        onStartBattle: (config) => started = config,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('categories come from the packs and balls can be mixed across them', (tester) async {
    await pumpSetup(tester);
    expect(find.text('My Balls'), findsOneWidget);
    expect(find.text('Shoes'), findsOneWidget);

    await tester.tap(find.text('United States'));
    await tester.tap(find.text('Shoes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BATTLE'));

    expect(started!.contestants.map((b) => b.name), ['United States', 'Nike']);
    expect(started!.contestants.last.id, 'pack:shoes/nike');
  });

  testWidgets('RANDOM MATCHUP picks two balls from the current category', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Shoes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RANDOM MATCHUP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START BATTLE'));

    expect(started!.contestants.length, 2);
    expect(started!.contestants.every((b) => b.id.startsWith('pack:shoes/')), isTrue);
  });

  testWidgets('big categories get a search box', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.text('Shoes'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Countries'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'phil');
    await tester.pumpAndSettle();
    expect(find.text('Philippines'), findsOneWidget);
    expect(find.text('Country 3'), findsNothing);
  });
}
