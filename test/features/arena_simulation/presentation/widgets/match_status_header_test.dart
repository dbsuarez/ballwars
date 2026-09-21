import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/widgets/match_status_header.dart';

void main() {
  testWidgets('shows title and round text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MatchStatusHeader(isSlowMotion: false)),
    ));

    expect(find.text('WHO WINS?'), findsOneWidget);
    expect(find.text('ROUND 1'), findsOneWidget);
  });

  testWidgets('hides the slow motion badge when not in slow motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MatchStatusHeader(isSlowMotion: false)),
    ));

    expect(find.text('SLOW MOTION'), findsNothing);
  });

  testWidgets('shows the slow motion badge when in slow motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MatchStatusHeader(isSlowMotion: true)),
    ));

    expect(find.text('SLOW MOTION'), findsOneWidget);
  });
}
