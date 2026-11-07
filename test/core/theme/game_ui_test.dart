import 'package:ballwars/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/game_ui.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/app.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';

void main() {
  testWidgets(
    'workbench builder gets game chrome and contrasting save controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppPalettes.midnight),
          home: GameWorkbench(
            builder: (context) => Scaffold(
              body: GameSkillFrame(
                color: GameUi.purple,
                child: const Text('Epic skill'),
              ),
              bottomNavigationBar: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(Scaffold));
      final theme = Theme.of(context);
      expect(BallWarsColors.of(context).background, GameUi.navy);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(find.byType(GameBackdrop), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      final style = theme.filledButtonTheme.style!;
      expect(
        style.foregroundColor!.resolve({}),
        isNot(style.backgroundColor!.resolve({})),
      );
      expect(button.onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('arcade styling preserves every non-default configured palette', (
    tester,
  ) async {
    for (final palette in AppPalettes.all) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(palette),
          home: GameTheme(
            child: Builder(
              builder: (context) =>
                  Scaffold(body: const GamePanel(child: Text('Palette'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(GamePanel));
      final c = BallWarsColors.of(context);
      expect(
        c.background,
        palette.id == 'midnight' ? GameUi.navy : palette.background,
        reason: palette.id,
      );
      expect(
        Theme.of(context).colorScheme.onSurface,
        c.text,
        reason: palette.id,
      );
      expect(
        Theme.of(context).colorScheme.primary,
        isNot(Theme.of(context).colorScheme.onPrimary),
      );
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('game theme preserves contrasting icon-button roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GameTheme(
          child: Scaffold(
            body: IconButton.filled(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(IconButton));
    final theme = Theme.of(context);
    expect(theme.iconButtonTheme.style?.foregroundColor, isNull);
    expect(theme.colorScheme.primary, GameUi.gold);
    expect(theme.colorScheme.onPrimary, GameUi.navy);
    expect(
      IconTheme.of(tester.element(find.byIcon(Icons.play_arrow))).color,
      GameUi.navy,
    );
  });
  testWidgets('gold action honors its disabled state and taps', (tester) async {
    var taps = 0;
    Widget app(bool enabled) => MaterialApp(
      home: GameTheme(
        child: Scaffold(
          body: Center(
            child: GameActionButton(
              label: 'Start',
              onPressed: enabled ? () => taps++ : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.tap(find.text('Start'));
    expect(taps, 0);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(app(true));
    await tester.tap(find.text('Start'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    '320px lobby scrolls with larger text and Play remembers its last mode',
    (tester) async {
      OfflineStore.instance = MemoryOfflineStore();
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const BallWarsApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Mayhem'));
      await tester.tap(find.text('Mayhem'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MatchSetupScreen>(find.byType(MatchSetupScreen))
            .initialMayhem,
        true,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('lobby-play')));
      await tester.tap(find.byKey(const ValueKey('lobby-play')));
      await tester.pumpAndSettle();
      final setup = tester.widget<MatchSetupScreen>(
        find.byType(MatchSetupScreen),
      );
      expect(setup.initialMode, MatchMode.arsenal);
      expect(setup.initialMayhem, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
