import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/app.dart';

void main() {
  testWidgets('BallWarsApp builds and shows title', (tester) async {
    await tester.pumpWidget(const BallWarsApp());
    expect(find.text('Ball Wars'), findsOneWidget);
  });
}
