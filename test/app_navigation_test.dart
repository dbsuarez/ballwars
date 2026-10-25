import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('home shows the headline and opens a new match and settings', (tester) async {
    await tester.pumpWidget(const BallWarsApp());
    await tester.pump();

    expect(find.text('BALL WARS'), findsOneWidget);
    expect(find.text('Start a match'), findsNothing);
    expect(find.text('Mayhem'), findsOneWidget);
    expect(find.text('All-Out'), findsOneWidget);
    expect(find.textContaining('Version '), findsOneWidget);
    expect(find.text('Who wins?'), findsOneWidget);
    // No backend in tests: My Groups is hidden.
    expect(find.text('My groups'), findsNothing);

    await tester.tap(find.text('Threads'));
    await tester.pumpAndSettle();
    expect(find.text('New match'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('connection to the Ball Wars server'), findsOneWidget);
  });
}
