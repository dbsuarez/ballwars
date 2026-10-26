import 'package:ballwars/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'filled icon buttons keep a contrasting foreground in every palette',
    (tester) async {
      for (final palette in AppPalettes.all) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(palette),
            home: const Scaffold(
              body: Center(
                child: IconButton.filled(
                  onPressed: _noop,
                  icon: Icon(Icons.play_arrow),
                ),
              ),
            ),
          ),
        );

        final button = tester.widget<IconButton>(find.byType(IconButton));
        final theme = Theme.of(tester.element(find.byType(IconButton)));
        expect(
          theme.iconButtonTheme.style?.foregroundColor,
          isNull,
          reason: palette.name,
        );
        expect(
          theme.colorScheme.primary,
          isNot(theme.colorScheme.onPrimary),
          reason: palette.name,
        );
        expect(button.style?.foregroundColor, isNull, reason: palette.name);
      }
    },
  );
}

void _noop() {}
