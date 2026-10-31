import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/arena_geometry_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editor applies independent rotation options and interval', (tester) async {
    ArenaGeometrySelection? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showArenaGeometryEditor(context,
            shape: ArenaShape.circle,
            obstacle: CenterObstacle.none,
            scale: 0.22,
          );
        },
        child: const Text('Edit arena'),
      ),
    ))));
    await tester.tap(find.text('Edit arena'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-rotate-themes')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-rotate-shapes')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('editor-rotate-themes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-rotate-themes')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('editor-rotation-interval')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-rotation-interval')), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.rotateThemes, isTrue);
    expect(result!.rotateShapes, isFalse);
    expect(result!.intervalSeconds, 60);
  });

  testWidgets('cancel does not apply arena edits', (tester) async {
    ArenaGeometrySelection? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async {
          result = await showArenaGeometryEditor(context,
            shape: ArenaShape.square,
            obstacle: CenterObstacle.circle,
            scale: 0.24,
          );
        },
        child: const Text('Edit arena'),
      ),
    ))));
    await tester.tap(find.text('Edit arena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
