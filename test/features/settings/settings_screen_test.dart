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
}
