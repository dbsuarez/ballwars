import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/data/local_ball_repository.dart';
import 'package:ballwars/features/ball_management/presentation/ball_library_screen.dart';

void main() {
  testWidgets('renders all balls from the repository', (tester) async {
    final repo = LocalBallRepository();
    await tester.pumpWidget(MaterialApp(
      home: BallLibraryScreen(repository: repo),
    ));

    expect(find.text('United States'), findsOneWidget);
    expect(find.text('Russia'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('Brazil'), findsOneWidget);
  });

  testWidgets('opens the ball editor dialog on Create New Ball tap', (tester) async {
    final repo = LocalBallRepository();
    await tester.pumpWidget(MaterialApp(
      home: BallLibraryScreen(repository: repo),
    ));

    await tester.tap(find.text('CREATE NEW BALL'));
    await tester.pumpAndSettle();

    expect(find.text('Create Ball'), findsOneWidget);
  });
}
