import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/power_up_test_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth implements AdminAuth {
  _Auth(this.allowed);
  final bool allowed;

  @override
  String? get email => allowed ? 'admin@example.com' : null;

  @override
  Future<bool> isAdmin() async => allowed;

  @override
  Future<void> signIn(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {}

  @override
  Future<void> signOut() async {}
}

Widget _app(bool admin) => AppSettingsScope(
  settings: ValueNotifier(AppSettings.defaults),
  adminAuth: _Auth(admin),
  child: MaterialApp(
    theme: AppTheme.build(AppPalettes.midnight),
    home: const PowerUpTestScreen(),
  ),
);

void main() {
  testWidgets('test arena rejects unauthenticated users', (tester) async {
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('admin can equip an item and watch, pause and reset the fight', (tester) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    final give = find.byTooltip('Give item again to Ball A');
    await tester.ensureVisible(give);
    await tester.tap(give);
    await tester.pump();
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
    await tester.tap(find.text('Reset fight'));
    await tester.pump();
    expect(find.text('Paused - 0.0 s'), findsOneWidget);
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.balls.first.held, PowerUpKind.pistol);
  });

  testWidgets('phone keeps playback and freeze controls visible while selecting an item', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();

    expect(find.text('A: Moving').hitTestable(), findsOneWidget);
    expect(find.text('B: Moving').hitTestable(), findsOneWidget);
    expect(find.text('Play').hitTestable(), findsOneWidget);
    await tester.tap(find.text('A: Moving'));
    await tester.pump();
    expect(find.text('A: Frozen'), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-item-0')).hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('choose-item-1')).hitTestable(), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
    await tester.tap(find.byKey(const ValueKey('choose-item-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shotgun');
    await tester.pump();
    expect(find.text('Shotgun'), findsOneWidget);
    await tester.tap(find.text('Shotgun'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset fight'));
    await tester.pump();
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.balls[1].held, PowerUpKind.shotgun);
    expect(find.text('A: Frozen').hitTestable(), findsOneWidget);
    expect(find.text('Play').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
