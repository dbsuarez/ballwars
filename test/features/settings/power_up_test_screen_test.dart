import 'package:ballwars/core/audio/game_audio.dart';
import 'package:ballwars/core/offline/device_prefs.dart';
import 'package:ballwars/core/offline/offline_store.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_preview.dart';
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

Widget _app(
  bool admin, {
  SkillDefinition? initialSkill,
  SkillLibrary? library,
}) => AppSettingsScope(
  settings: ValueNotifier(AppSettings.defaults.copyWith(skillLibrary: library)),
  adminAuth: _Auth(admin),
  child: MaterialApp(
    theme: AppTheme.build(AppPalettes.midnight),
    home: PowerUpTestScreen(initialSkill: initialSkill),
  ),
);

void main() {
  testWidgets(
    'custom knife and built-in knife keep separate identities in both slots and picker',
    (tester) async {
      final previous = OfflineStore.instance;
      OfflineStore.instance = MemoryOfflineStore();
      addTearDown(() => OfflineStore.instance = previous);
      final knife = SkillLibrary.defaults.builtIn(
        PowerUpKind.knife,
        AppSettings.defaults.powerUps,
      );
      final custom = SkillLibrary.defaults
          .duplicate(knife, 'Kutsilyo')
          .copyWith(arsenalDamage: 31);
      final library = SkillLibrary.defaults.withDefinition(
        custom,
        AppSettings.defaults.powerUps,
      );
      await tester.pumpWidget(
        _app(true, initialSkill: custom, library: library),
      );
      await tester.pumpAndSettle();
      final second = find.byKey(const ValueKey('choose-weapon-2-0'));
      await tester.longPress(second);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'knife');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('power-test-item-knife')));
      await tester.pumpAndSettle();
      var ball = tester
          .widget<ArenaCanvas>(find.byType(ArenaCanvas))
          .state
          .balls
          .first;
      expect(ball.heldSkillId, custom.id);
      expect(ball.heldSecondarySkillId, knife.id);
      await tester.tap(find.byKey(const ValueKey('choose-item-0')));
      await tester.pump();
      expect(ball.heldSkillId, custom.id);
      expect(ball.heldSecondarySkillId, knife.id);
      await tester.tap(find.byKey(const ValueKey('clear-loadout-0')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('choose-item-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Kutsilyo');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Kutsilyo'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('power-test-skill-${custom.id}')));
      await tester.pumpAndSettle();
      await tester.longPress(second);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'knife');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('power-test-item-knife')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(true, library: library));
      await tester.pumpAndSettle();
      ball = tester
          .widget<ArenaCanvas>(find.byType(ArenaCanvas))
          .state
          .balls
          .first;
      expect(ball.heldSkillId, custom.id);
      expect(ball.heldSecondarySkillId, knife.id);
    },
  );
  testWidgets('test arena rejects unauthenticated users', (tester) async {
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();
    expect(find.text('Admin access required.'), findsOneWidget);
    expect(find.byTooltip('Play'), findsNothing);
  });

  testWidgets('admin can equip an item and watch, pause and reset the fight', (
    tester,
  ) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('choose-power-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('power-test-item-apple')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Play'));
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset Fight'));
    await tester.pump();
    expect(find.text('Paused - 0.0 s'), findsOneWidget);
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.balls.first.life, greaterThan(100));
  });

  testWidgets(
    'slot tap rearms and hold opens selection without refresh buttons',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rearm-loadout-0')), findsNothing);
      expect(find.byKey(const ValueKey('rearm-weapon-1-0')), findsNothing);
      expect(find.byKey(const ValueKey('rearm-power-0')), findsNothing);
      expect(find.byKey(const ValueKey('clear-weapon-1-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-weapon-2-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-power-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('clear-loadout-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('rearm-all-arena-traps')), findsNothing);
      expect(
        find.byKey(const ValueKey('clear-all-arena-traps')),
        findsOneWidget,
      );
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('choose-arena-trap-$i')), findsOneWidget);
        expect(find.byKey(ValueKey('rearm-arena-trap-$i')), findsNothing);
        expect(find.byKey(ValueKey('clear-arena-trap-$i')), findsOneWidget);
      }
      final before = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
      before.state.balls.first.held = null;
      await tester.tap(find.byKey(const ValueKey('choose-item-0')));
      await tester.pump();
      final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
      expect(arena.state.balls.first.held, PowerUpKind.pistol);

      await tester.longPress(find.byKey(const ValueKey('choose-item-0')));
      await tester.pumpAndSettle();
      expect(find.text('Weapons'), findsOneWidget);
    },
  );

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
    'phone gives the arena full width and keeps controls available by scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();

      final motionA = find.byKey(const ValueKey('motion-A'));
      final motionB = find.byKey(const ValueKey('motion-B'));
      expect(motionA.hitTestable(), findsOneWidget);
      expect(motionB.hitTestable(), findsOneWidget);
      expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
      expect(
        tester.getSize(find.byType(ArenaCanvas)).width,
        greaterThanOrEqualTo(385),
      );
      final movingVelocity = tester
          .widget<ArenaCanvas>(find.byType(ArenaCanvas))
          .state
          .balls
          .first
          .velocity;
      await tester.tap(
        find.descendant(of: motionA, matching: find.text('Random')),
      );
      await tester.pump();
      final randomVelocity = tester
          .widget<ArenaCanvas>(find.byType(ArenaCanvas))
          .state
          .balls
          .first
          .velocity;
      expect(randomVelocity, isNot(movingVelocity));
      await tester.tap(
        find.descendant(of: motionA, matching: find.text('Idle')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('choose-item-1')),
        260,
        scrollable: find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.longPress(find.byKey(const ValueKey('choose-item-1')));
      await tester.pumpAndSettle();
      expect(find.text('Weapons'), findsOneWidget);
      expect(find.text('Boomerang').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'shotgun');
      await tester.pump();
      expect(find.text('Shotgun'), findsOneWidget);
      await tester.tap(find.text('Shotgun'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reset Fight'));
      await tester.pump();
      final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
      expect(arena.state.balls[1].held, PowerUpKind.shotgun);
      expect(find.byTooltip('Play').hitTestable(), findsOneWidget);
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
      final preview = find.byKey(const ValueKey('finisher-preview-0-0'));
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
      expect(find.byTooltip('Play'), findsOneWidget);
    },
  );

  testWidgets('damaging power-ups expose a finisher control in the arena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('choose-power-0')),
      300,
      scrollable: find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('choose-power-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'raging demon');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('power-test-item-ragingDemon')));
    await tester.pumpAndSettle();

    final preview = find.byKey(const ValueKey('finisher-preview-0-2'));
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    expect(preview.hitTestable(), findsOneWidget);
    expect(tester.widget<InkWell>(preview).onTap, isNotNull);
    expect(
      find.byTooltip('Preview Raging Demon finisher for Ball A'),
      findsOneWidget,
    );
  });

  testWidgets('tests default to endless and expose BGM, SFX and UX controls', (
    tester,
  ) async {
    final audio = GameAudio.instance;
    final originalMusic = audio.musicOn;
    final originalEffects = audio.effectsOn;
    final originalUx = audio.uxOn;
    addTearDown(() async {
      await audio.setMusicOn(originalMusic);
      await audio.setEffectsOn(originalEffects);
      await audio.setUxOn(originalUx);
    });
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.state.powerUps!.match.endlessBattle, isTrue);
    expect(
      find.byKey(const ValueKey('audio-BGM')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('audio-SFX')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('audio-UX')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('audio-SFX')));
    await tester.pumpAndSettle();
    expect(audio.effectsOn, !originalEffects);
    await tester.tap(find.byKey(const ValueKey('audio-BGM')));
    await tester.pumpAndSettle();
    expect(audio.musicOn, !originalMusic);
  });

  testWidgets('each ball has two weapon selectors and one power-up selector', (
    tester,
  ) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      expect(find.byKey(ValueKey('choose-item-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('choose-weapon-2-$i')), findsOneWidget);
      expect(find.byKey(ValueKey('choose-power-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('choose-arena-trap-0')), findsOneWidget);
  });

  testWidgets('separate selectors keep searches inside their item category', (
    tester,
  ) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const ValueKey('choose-power-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump();
    expect(find.text('Apple'), findsWidgets);
    expect(find.text('Power-ups'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Apple'), findsWidgets);
    expect(find.text('Boomerang'), findsNothing);
    expect(find.text('Results from all categories'), findsNothing);
  });

  testWidgets(
    'the remembered item is selected and placed first in its picker',
    (tester) async {
      await tester.pumpWidget(_app(true));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('choose-item-0')));
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

  testWidgets('changing a test item preserves the live ball positions', (
    tester,
  ) async {
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    final before = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    before.state.balls[0].position = const Offset(31, 47);
    before.state.balls[1].position = const Offset(-62, 19);

    await tester.longPress(find.byKey(const ValueKey('choose-item-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'shotgun');
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('power-test-item-shotgun')).hitTestable(),
    );
    await tester.pumpAndSettle();

    final after = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(after.state.balls[0].position, const Offset(31, 47));
    expect(after.state.balls[1].position, const Offset(-62, 19));
  });

  testWidgets('change arena dialog previews arenas and applies the pick', (
    tester,
  ) async {
    OfflineStore.instance = MemoryOfflineStore();
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('test-arena')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('test-arena')));
    await tester.pumpAndSettle();
    final grid = find
        .descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final d in ArenaDecoration.values) {
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('arena-option-${d.name}')),
        100,
        scrollable: grid,
      );
      expect(find.byKey(ValueKey('arena-option-${d.name}')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('arena-option-${d.name}')),
          matching: find.byType(ArenaPreview),
        ),
        findsOneWidget,
      );
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('arena-option-desert')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arena-option-desert')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('arena-option-desert')), findsNothing);
    final arena = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas));
    expect(arena.arenaDecoration, ArenaDecoration.desert);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('test-arena')),
        matching: find.text('Desert'),
      ),
      findsOneWidget,
    );
    expect(await DevicePrefs.read('power-test-arena'), 'desert');
  });

  testWidgets('change arena dialog marks the active arena with a check', (
    tester,
  ) async {
    OfflineStore.instance = MemoryOfflineStore();
    await DevicePrefs.write('power-test-arena', 'space');
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('test-arena')));
    await tester.pumpAndSettle();
    Finder checkIn(ArenaDecoration d) => find.descendant(
      of: find.byKey(ValueKey('arena-option-${d.name}')),
      matching: find.byIcon(Icons.check_circle),
    );
    for (final d in ArenaDecoration.values) {
      expect(
        checkIn(d),
        d == ArenaDecoration.space ? findsOneWidget : findsNothing,
        reason: d.name,
      );
    }
    // Every tile keeps its hazard caption.
    expect(find.text(ArenaDecoration.space.hazardCaption), findsOneWidget);
    final grid = find
        .descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('arena-option-chaotic')),
      100,
      scrollable: grid,
    );
    expect(find.text('All arena traps'), findsOneWidget);
  });

  testWidgets('bottom bar fits at 360 px', (tester) async {
    OfflineStore.instance = MemoryOfflineStore();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
