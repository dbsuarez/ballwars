import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/legal/app_licenses.dart';
import 'package:ballwars/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all bundled visual-asset notices load with attribution', () async {
    final entries = await AppLicenses.entries().toList();
    expect(entries.map((e) => e.packages.single).toList(), [
      'Manrope',
      'JetBrains Mono',
      'Material Design icons (Google)',
    ]);
    for (final entry in entries) {
      expect(
        entry.paragraphs.map((p) => p.text).join(' ').length,
        greaterThan(100),
      );
    }
  });
  testWidgets('public lobby exposes the credits and licenses action', (
    tester,
  ) async {
    await tester.pumpWidget(const BallWarsApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Credits & licenses'));
    expect(find.text('Credits & licenses').hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Credits & licenses'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
