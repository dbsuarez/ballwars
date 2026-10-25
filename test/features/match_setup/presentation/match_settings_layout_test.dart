import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => OfflineStore.instance = MemoryOfflineStore());

  for (final cards in [false, true]) {
    testWidgets('remembered layout opens as ${cards ? "individual cards" : "list"}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => DevicePrefs.write('match-settings-layout', cards ? 'cards' : 'list'));
      await tester.pumpWidget(MaterialApp(theme: AppTheme.build(AppPalettes.midnight),
          home: MatchSetupScreen(onStartBattle: (_) {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit match settings'));
      await tester.pumpAndSettle();
      final rounds = find.byKey(const ValueKey('setting-Rounds'));
      final width = tester.getSize(rounds).width;
      if (cards) {
        expect(find.byKey(const ValueKey('individual-setting-card')), findsWidgets);
        expect(width, inExclusiveRange(100.0, 250.0));
      } else {
        expect(find.byKey(const ValueKey('individual-setting-card')), findsNothing);
        expect(width, greaterThan(300));
      }
      final rect = tester.getRect(rounds);
      await tester.tapAt(Offset(rect.left + 4, rect.center.dy));
      await tester.pump();
      expect(find.text('First to 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('match-settings-all-set')).hitTestable(), findsOneWidget);
      await tester.tap(find.text(cards ? 'List' : 'Cards'));
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(() => DevicePrefs.read('match-settings-layout'));
      expect(saved, cards ? 'list' : 'cards');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('fresh devices default to Cards with the selector at the top right', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.build(AppPalettes.midnight),
        home: MatchSetupScreen(onStartBattle: (_) {})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit match settings'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('individual-setting-card')), findsWidgets);
    final selector = find.byKey(const ValueKey('match-settings-layout'));
    final selection = tester.widget<SegmentedButton<bool>>(selector).selected;
    expect(selection, {true});
    final selectorRect = tester.getRect(selector);
    final roundsRect = tester.getRect(find.byKey(const ValueKey('setting-Rounds')));
    expect(selectorRect.bottom, lessThanOrEqualTo(roundsRect.top));
    expect(tester.takeException(), isNull);
  });

}
