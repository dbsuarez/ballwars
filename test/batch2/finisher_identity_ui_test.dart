import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_battle_screen.dart';
import 'package:ballwars/features/arena_simulation/presentation/arena_canvas.dart';
import 'package:ballwars/features/arena_simulation/presentation/harpoon_cinematic.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_sprites.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'package:ballwars/features/settings/data/app_settings_repository.dart';
import 'package:ballwars/features/settings/domain/app_settings.dart';
import 'package:ballwars/features/settings/presentation/app_settings_scope.dart';
import 'package:ballwars/features/settings/presentation/finisher_gallery_screen.dart';

class _Admin implements AdminAuth {
  @override
  Future<bool> isAdmin() async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const balls = [
  CustomBall(
    id: 'a',
    name: 'A',
    primaryColor: Colors.red,
    glowColor: Colors.orange,
  ),
  CustomBall(
    id: 'b',
    name: 'B',
    primaryColor: Colors.blue,
    glowColor: Colors.cyan,
  ),
];
void main() {
  setUpAll(() => Future<void>.sync(PowerUpSprites.load));
  testWidgets(
    'live winning cinematic receives the actual duplicate-name skill snapshot',
    (tester) async {
      var library = SkillLibrary.defaults;
      final base = library.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults);
      final first = library
          .duplicate(base, 'Same name')
          .copyWith(arsenalDamage: 300, spriteTint: 0xffff0000);
      library = library.withDefinition(first, PowerUpConfig.defaults);
      final second = library
          .duplicate(base, 'Same name')
          .copyWith(
            arsenalDamage: 300,
            projectileSpeed: 2,
            range: 2,
            spriteTint: 0xff00ff00,
          );
      library = library.withDefinition(second, PowerUpConfig.defaults);
      await tester.pumpWidget(
        MaterialApp(
          home: ArenaBattleScreen(
            seed: 1,
            config: MatchConfig(
              contestants: balls,
              mode: MatchMode.arsenal,
              powerUps: {},
              customSkills: {},
              skillLibrary: library,
              finishersEnabled: true,
              automaticSpeedUp: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      final state = tester.widget<ArenaCanvas>(find.byType(ArenaCanvas)).state;
      state.balls[0]
        ..position = const Offset(-100, 0)
        ..velocity = Offset.zero
        ..held = PowerUpKind.pistol
        ..heldSkillId = second.id;
      state.balls[1]
        ..position = const Offset(100, 0)
        ..velocity = Offset.zero;
      for (
        var i = 0;
        i < 350 && find.byType(HarpoonCinematic).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(find.byType(HarpoonCinematic), findsOneWidget);
      final cinematic = tester.widget<HarpoonCinematic>(
        find.byType(HarpoonCinematic),
      );
      expect(cinematic.skill!.id, second.id);
      expect(cinematic.artworkTint, 0xff00ff00);
      expect(cinematic.move, 'Same name');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'gallery uses the built-in ID when another skill owns its old display name',
    (tester) async {
      var library = SkillLibrary.defaults;
      final base = library.builtIn(PowerUpKind.pistol, PowerUpConfig.defaults);
      final renamed = base.copyWith(
        name: 'Golden pistol',
        spriteTint: 0xffffcc00,
      );
      library = library.withDefinition(renamed, PowerUpConfig.defaults);
      final custom = library
          .duplicate(base, 'Pistol')
          .copyWith(spriteTint: 0xff00ff00);
      library = library.withDefinition(custom, PowerUpConfig.defaults);
      final settings = ValueNotifier(
        AppSettings.defaults.copyWith(skillLibrary: library),
      );
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        AppSettingsScope(
          settings: settings,
          adminAuth: _Admin(),
          child: const MaterialApp(home: FinisherGalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final play = find.byKey(const ValueKey('play-finisher-Pistol'));
      await tester.ensureVisible(play);
      await tester.tap(play);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final cinematic = tester.widget<HarpoonCinematic>(
        find.byType(HarpoonCinematic),
      );
      expect(cinematic.skill!.id, base.id);
      expect(cinematic.artworkTint, 0xffffcc00);
      expect(cinematic.move, 'Golden pistol');
      await tester.pumpWidget(const SizedBox());
    },
  );
}
