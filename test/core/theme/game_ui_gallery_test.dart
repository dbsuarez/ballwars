import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/features/lobby/presentation/game_ui_gallery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(360, 800),
    const Size(800, 360),
    const Size(440, 900),
  ]) {
    testWidgets('component gallery is usable at ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (_, child) => RepaintBoundary(
            key: const ValueKey('gallery-root'),
            child: AppFrame(child: child!),
          ),
          home: const GameUiGallery(),
        ),
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('GAME_UI_GOLDENS')) {
        await expectLater(
          find.byKey(const ValueKey('gallery-root')),
          matchesGoldenFile(
            '../../goldens/game-ui-${size.width.toInt()}x${size.height.toInt()}.png',
          ),
        );
      }
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byType(SwitchListTile),
        180,
        scrollable: list,
      );
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, true);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: list,
      );
      await tester.enterText(find.byType(TextField), 'Arcade preset');
      await tester.pumpAndSettle();
      expect(find.text('Arcade preset'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
