import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arenas/domain/arena_catalog.dart';
import 'package:ballwars/features/arenas/domain/arena_theme.dart';
import 'package:ballwars/features/arenas/presentation/arena_library_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_selection_dialog.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_preview.dart';

const arena = ArenaDefinition(
  id: 'custom-map',
  name: 'Custom map',
  theme: ArenaDecoration.desert,
  trapTheme: ArenaDecoration.neonGrid,
);
void main() {
  testWidgets('phone editor preserves drafts across tabs and failed saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var fail = true;
    ArenaDefinition? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppPalettes.midnight),
        home: ArenaEditorScreen(
          initial: arena,
          onSave: (value) async {
            if (fail) throw StateError('Offline - retry');
            saved = value;
          },
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('arena-name')),
      'Sun court',
    );
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geometry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Identity'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('arena-name')))
          .controller!
          .text,
      'Sun court',
    );
    await tester.tap(find.byKey(const ValueKey('save-arena')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline - retry'), findsOneWidget);
    expect(find.byKey(const ValueKey('arena-name')), findsOneWidget);
    fail = false;
    await tester.tap(find.byKey(const ValueKey('save-arena')));
    await tester.pumpAndSettle();
    expect(saved!.name, 'Sun court');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'custom arena selection returns its definition and trap identity',
    (tester) async {
      ArenaDefinition? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open'),
                onPressed: () => showDialog<ArenaDecoration>(
                  context: context,
                  builder: (_) => ArenaSelectionDialog(
                    selected: ArenaDecoration.defaultArena,
                    presets: const [arena],
                    onSelectPreset: (value) => picked = value,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ArenaPreview>(
              find.descendant(
                of: find.byKey(const ValueKey('arena-option-custom-map')),
                matching: find.byType(ArenaPreview),
              ),
            )
            .arena,
        same(arena),
      );
      await tester.tap(find.byKey(const ValueKey('arena-option-custom-map')));
      await tester.pumpAndSettle();
      expect(picked, same(arena));
      expect(tester.takeException(), isNull);
    },
  );
}
