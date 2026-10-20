import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/neon_button.dart';

void main() {
  testWidgets('NeonButton renders label and triggers onPressed', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NeonButton(
          label: 'START BATTLE',
          onPressed: () => tapped = true,
        ),
      ),
    ));

    expect(find.text('START BATTLE'), findsOneWidget);

    final buttonSize = tester.getSize(find.byType(NeonButton));
    expect(buttonSize.width, greaterThanOrEqualTo(44));
    expect(buttonSize.height, greaterThanOrEqualTo(44));

    await tester.tap(find.byType(NeonButton));
    expect(tapped, isTrue);
  });
}
