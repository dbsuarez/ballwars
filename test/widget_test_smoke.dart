import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('BallWarsApp builds and shows title', (tester) async {
    await tester.pumpWidget(const BallWarsApp());
    await tester.pumpAndSettle();
    expect(find.text('BALL WARS'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-play')), findsOneWidget);
  });
}
