import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('home screen navigates to match setup and starts a battle', (tester) async {
    await tester.pumpWidget(const BallWarsApp());

    expect(find.text('MATCH SETUP'), findsOneWidget);
    await tester.tap(find.text('MATCH SETUP'));
    await tester.pumpAndSettle();

    expect(find.text('Select 2-4 Balls'), findsOneWidget);

    await tester.tap(find.text('United States'));
    await tester.tap(find.text('Russia'));
    await tester.pump();

    await tester.tap(find.text('START BATTLE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byType(Scaffold), findsWidgets);

    // Stop tickers cleanly before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
