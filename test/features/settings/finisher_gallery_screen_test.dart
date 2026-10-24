import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/finisher_profile.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/finisher_gallery_screen.dart';
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
    home: const FinisherGalleryScreen(),
  ),
);

void main() {
  testWidgets('only an authenticated admin can see finisher controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.byTooltip('Play Hook finisher'), findsNothing);
  });

  testWidgets('admin gallery lists every item and plays the real cinematic', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();

    expect(find.text('WEAPONS'), findsOneWidget);
    expect(FinisherProfile.coversEveryArenaItem, isTrue);
    expect(PowerUpKind.values, hasLength(32));

    final playPistol = find.byKey(const ValueKey('play-finisher-Pistol'));
    expect(playPistol, findsOneWidget);
    await tester.ensureVisible(playPistol);
    await tester.tap(playPistol);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HarpoonCinematic), findsOneWidget);
    expect(find.text('FINISHING MOVE'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4400));
    await tester.pumpAndSettle();
    expect(find.text('Finisher Gallery'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('finisher-stickyGoo')),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('TRAPS'), findsOneWidget);
    expect(find.byTooltip('Play Sticky Goo finisher'), findsOneWidget);
  });
}
