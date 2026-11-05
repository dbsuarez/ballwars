import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/core/widgets/app_frame.dart';
import 'package:ballwars/features/ball_packs/data/ball_pack_repository.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/match_setup/presentation/match_setup_screen.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('actual match setup starts at ${size.width}x${size.height}', (
      tester,
    ) async {
      OfflineStore.instance = MemoryOfflineStore();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      MatchConfig? started;
      final packs = BallPackRepository(
        baseUri: Uri.parse('http://localhost:1/'),
        fetch: (_) async =>
            '''{"version":1,"groups":[{"id":"test","name":"Test balls","style":"flag","balls":[{"id":"a","name":"A","image":"a.svg","color":"#FF5555"},{"id":"b","name":"B","image":"b.svg","color":"#5555FF"}]}]}''',
      );
      await tester.pumpWidget(
        AppSettingsScope(
          settings: ValueNotifier(AppSettings.defaults),
          child: MaterialApp(
            builder: (_, child) => AppFrame(child: child!),
            home: MatchSetupScreen(
              initialMode: MatchMode.arsenal,
              packRepository: packs,
              onStartBattle: (config) => started = config,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byIcon(Icons.shuffle));
      await tester.tap(find.byIcon(Icons.shuffle));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('start-battle')));
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(started, isNotNull);
      expect(started!.mode, MatchMode.arsenal);
      expect(started!.contestants.length, 2);
      await tester.ensureVisible(find.byType(DropdownMenu<String>));
      final editable = find.descendant(of:find.byType(DropdownMenu<String>),matching:find.byType(EditableText));
      final focus = tester.widget<EditableText>(editable).focusNode;
      focus.requestFocus(); await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom:180); await tester.pump();
      expect(focus.hasFocus,isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
