import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/widgets/match_status_header.dart';

void main() {
  testWidgets('shows the headline and the round label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MatchStatusHeader(headline: "WHO'S BETTER?", subtitle: 'ROUND 2'))),
    );
    expect(find.text("WHO'S BETTER?"), findsOneWidget);
    expect(find.text('ROUND 2'), findsOneWidget);
  });

  testWidgets('the slow-motion badge reads SLOW MOTION', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SlowMotionBadge()))));
    expect(find.text('SLOW MOTION'), findsOneWidget);
  });
}
