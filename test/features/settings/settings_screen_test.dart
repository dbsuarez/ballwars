import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/settings_screen.dart';

class _FakeRepo implements AppSettingsRepository {
  final List<AppSettings> saved = [];

  @override
  Future<AppSettings> load() async => AppSettings.defaults;

  @override
  Future<void> save(AppSettings settings) async => saved.add(settings);
}

class _Admin implements AdminAuth {
  @override
  Future<bool> isAdmin() async => true;

  @override
  String? get email => 'admin@example.com';

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('the admin picks the match music for everyone and can play each track', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    final settings = ValueNotifier(AppSettings.defaults);
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        repository: repo,
        adminAuth: _Admin(),
        child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MUSIC'), findsOneWidget);
    for (final name in ['Arena', 'Turbo', 'Sunny Day', 'Boss Fight', 'Chill Out']) {
      expect(find.text(name), findsOneWidget);
      expect(find.byTooltip('Play $name'), findsOneWidget);
    }

    await tester.tap(find.text('Boss Fight'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.musicId, 'boss');
    expect(settings.value.musicId, 'boss');
  });

  testWidgets('the admin sets when slow motion starts', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    final settings = ValueNotifier(AppSettings.defaults);
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        repository: repo,
        adminAuth: _Admin(),
        child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('down to 10 lines'), findsOneWidget);
    await tester.drag(find.byType(Slider), const Offset(-2000, 0)); // all the way left: off
    await tester.pumpAndSettle();
    expect(find.text('Off: matches never slow down.'), findsOneWidget);
    await tester.tap(find.text('Save slow motion'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.slowMotionLines, 0);
  });

  testWidgets('the admin can switch slow motion to before the win', (tester) async {
    tester.view.physicalSize = const Size(1080, 5000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo();
    await tester.pumpWidget(
      AppSettingsScope(
        settings: ValueNotifier(AppSettings.defaults),
        repository: repo,
        adminAuth: _Admin(),
        child: MaterialApp(theme: AppTheme.build(AppPalettes.midnight), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Before the win'));
    await tester.pumpAndSettle();
    expect(find.text('Starts 1.5 s before the winning cut.'), findsOneWidget);
    await tester.tap(find.text('Save slow motion'));
    await tester.pumpAndSettle();
    expect(repo.saved.single.slowMotionBeforeWinSeconds, 1.5);
  });
}
