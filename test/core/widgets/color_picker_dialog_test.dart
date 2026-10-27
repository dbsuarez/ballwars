import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/color_picker_dialog.dart';

void main() {
  testWidgets('color picker selects colors visually without hex input', (
    tester,
  ) async {
    Color? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showColorPicker(context, initialColor: Colors.red);
            },
            child: const Text('Pick'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.tap(find.bySemanticsLabel('Color swatch').at(5));
    await tester.tap(find.text('Use color'));
    await tester.pumpAndSettle();
    expect(result?.toARGB32(), Colors.blue.toARGB32());
  });
}
