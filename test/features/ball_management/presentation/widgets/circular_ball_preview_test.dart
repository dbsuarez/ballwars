import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/ball_management/presentation/widgets/circular_ball_preview.dart';

void main() {
  testWidgets('shows initials when no image is set', (tester) async {
    const ball = CustomBall(
      id: 'x',
      name: 'Neon Dragon',
      primaryColor: Colors.purple,
      glowColor: Colors.pink,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CircularBallPreview(ball: ball)),
    ));

    expect(find.text('ND'), findsOneWidget);
  });

  testWidgets('renders at the requested size', (tester) async {
    const ball = CustomBall(
      id: 'x',
      name: 'A',
      primaryColor: Colors.purple,
      glowColor: Colors.pink,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CircularBallPreview(ball: ball, size: 120)),
    ));

    final size = tester.getSize(find.byType(CircularBallPreview));
    expect(size.width, 120);
    expect(size.height, 120);
  });
}
