import 'package:ballwars/core/audio/game_audio.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/core/theme/app_theme.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/power_up_test_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
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

Widget _app(bool admin, {SkillDefinition? initialSkill}) => AppSettingsScope(
  settings: ValueNotifier(AppSettings.defaults),
  adminAuth: _Auth(admin),
  child: MaterialApp(
    theme: AppTheme.build(AppPalettes.midnight),
    home: PowerUpTestScreen(initialSkill: initialSkill),
  ),
);

void main() {
  testWidgets('test arena rejects unauthenticated users', (tester) async {
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.text('Play'), findsNothing);
  });

  testWidgets('admin can equip an item and watch, pause and reset the fight', (
    tester,
  ) async {
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

  testWidgets('an unsaved skill opens preselected in the live test arena', (
    tester,
  ) async {
    final draft = SkillLibrary.defaults
        .create('Instant Rush', PowerUpKind.speed)
        .copyWith(
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.instant,
          effectType: SkillEffectType.speed,
          durationSeconds: 4,
        );
    await tester.pumpWidget(_app(true, initialSkill: draft));
    await tester.pumpAndSettle();

    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.balls.first.speedLeft, 4 * 60);
  });

  testWidgets(
    'phone keeps playback and freeze controls visible while selecting an item',
    (tester) async {
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
      expect(
        find.byKey(const ValueKey('choose-item-0')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('choose-item-1')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(Scrollable), findsNothing);
      await tester.tap(find.byKey(const ValueKey('choose-item-1')));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Boomerang').hitTestable(), findsOneWidget);
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
    },
  );
  testWidgets(
    'arena corner icon previews the selected finisher without changing the fight',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();
      final initial = tester
          .widget<ArenaCanvas>(find.byType(ArenaCanvas))
          .state;
      final preview = find.byKey(const ValueKey('item-preview-0'));
      expect(preview.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('item-preview-1')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(preview);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final cinematic = tester.widget<HarpoonCinematic>(
        find.byType(HarpoonCinematic),
      );
      expect(cinematic.move, 'Pistol');
      expect(cinematic.winner.name, 'Ball A');
      expect(cinematic.loser.name, 'Ball B');
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      final after = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas)).state;
      expect(after.step, initial.step);
      expect(after.balls.first.held, PowerUpKind.pistol);
      expect(find.text('Play'), findsOneWidget);
    },
  );

  testWidgets('tests default to endless and expose BG and SFX toggles', (
    tester,
  ) async {
    final audio = GameAudio.instance;
    final originalMusic = audio.musicOn;
    final originalEffects = audio.effectsOn;
    addTearDown(() async {
      await audio.setMusicOn(originalMusic);
      await audio.setEffectsOn(originalEffects);
    });
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.powerUps!.match.endlessBattle, isTrue);
    expect(find.text('BG').hitTestable(), findsOneWidget);
    expect(find.text('SFX').hitTestable(), findsOneWidget);
    await tester.tap(find.text('SFX'));
    await tester.pumpAndSettle();
    expect(audio.effectsOn, !originalEffects);
    await tester.tap(find.text('BG'));
    await tester.pumpAndSettle();
    expect(audio.musicOn, !originalMusic);
  });

  testWidgets(
    'item info beside re-equip explains the selected power and pauses',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.tap(find.byTooltip('Item info for Ball A'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Pistol'), findsWidgets);
      expect(find.textContaining('fires one shot'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Play'), findsOneWidget);
    },
  );

  testWidgets(
    'search spans all categories and clearing restores the selected tab',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-item-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'apple');
      await tester.pump();
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Results from all categories'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Boomerang'), findsOneWidget);
      expect(find.text('Results from all categories'), findsNothing);
    },
  );

  testWidgets(
    'the remembered item is selected and placed first in its picker',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('choose-item-0')));
      await tester.pumpAndSettle();

      final pistol = find.byKey(const ValueKey('power-test-item-pistol'));
      expect(pistol, findsOneWidget);
      expect(tester.widget<ListTile>(pistol).selected, isTrue);
      expect(
        find.descendant(of: pistol, matching: find.byIcon(Icons.check_circle)),
        findsOneWidget,
      );
      final visibleTiles = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(ListTile),
      );
      expect(
        visibleTiles.evaluate().first.widget.key,
        const ValueKey('power-test-item-pistol'),
      );
    },
  );
}
