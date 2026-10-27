import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ballwars/app.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';

void main() {
  testWidgets('home shows the headline and opens a new match and settings', (
    tester,
  ) async {
    await tester.pumpWidget(const BallWarsApp());
    await tester.pump();

    expect(find.text('BALL WARS'), findsOneWidget);
    expect(find.text('Start a match'), findsNothing);
    expect(find.text('Arsenal'), findsOneWidget);
    expect(find.text('Mayhem'), findsOneWidget);
    expect(find.text('All-Out'), findsOneWidget);
    expect(find.textContaining('Version '), findsOneWidget);
    expect(find.text('Who wins?'), findsOneWidget);
    // No backend in tests: My Groups is hidden.
    expect(find.text('My groups'), findsNothing);

    await tester.tap(find.text('Threads'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Threads')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    for (final choice in [
      ('Arsenal', MatchMode.arsenal, false),
      ('Mayhem', MatchMode.arsenal, true),
      ('All-Out', MatchMode.allOut, false),
    ]) {
      await tester.tap(find.text(choice.$1));
      await tester.pumpAndSettle();
      final setup = tester.widget<MatchSetupScreen>(
        find.byType(MatchSetupScreen),
      );
      expect(setup.initialMode, choice.$2);
      expect(setup.initialMayhem, choice.$3);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.textContaining('connection to the Ball Wars server'),
      findsOneWidget,
    );
  });
}
