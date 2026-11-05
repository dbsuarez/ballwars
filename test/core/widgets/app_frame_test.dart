import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/core/theme/app_theme.dart';

void main() {
  for (final width in [320.0, 390.0, 800.0, 1440.0]) {
    testWidgets('routes dialogs and sheets share the Home width at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final expected = width.clamp(0, AppFrame.maxWidth);
      Widget page(String title) => Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Column(
            children: [
              Text('Viewport ${MediaQuery.sizeOf(context).width}'),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page('Next')),
                ),
                child: const Text('Next route'),
              ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Dialog'),
                    content: Text('Contents'),
                  ),
                ),
                child: const Text('Open dialog'),
              ),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    key: ValueKey('sheet-content'),
                    height: 100,
                    child: Text('Sheet'),
                  ),
                ),
                child: const Text('Open sheet'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          builder: (_, child) => AppFrame(child: child!),
          home: page('Home'),
        ),
      );
      expect(tester.getSize(find.byType(Scaffold)).width, expected);
      expect(find.text('Viewport $expected'), findsOneWidget);
      await tester.tap(find.text('Next route'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(Scaffold).last).width, expected);
      expect(
        tester.getRect(find.byType(Scaffold).last).left,
        (width - expected) / 2,
      );
      await tester.tap(find.text('Open dialog').last);
      await tester.pumpAndSettle();
      final surface = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      expect(tester.getSize(surface).width, expected);
      expect(tester.getSize(surface).height, lessThan(250));
      final context = tester.element(find.byType(AlertDialog));
      Navigator.pop(context);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open sheet').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(
              find
                  .descendant(
                    of: find.byType(BottomSheet),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .width,
        expected,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
