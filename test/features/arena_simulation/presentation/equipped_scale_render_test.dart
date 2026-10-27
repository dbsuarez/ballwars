import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up_config.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';

void main() {
  testWidgets(
    'equipped scale changes rendered pixels for guns, blades, shields and flails',
    (tester) async {
      for (final kind in [
        PowerUpKind.pistol,
        PowerUpKind.sword,
        PowerUpKind.shield,
        PowerUpKind.orbitingFlail,
      ]) {
        final custom = SkillLibrary.defaults
            .duplicate(
              SkillLibrary.defaults.builtIn(kind, PowerUpConfig.defaults),
              'Large ${kind.name}',
            )
            .copyWith(weaponDisplayScale: 2.5);
        final match = MatchSimulationController(
          const [
            CustomBall(
              id: 'a',
              name: 'A',
              primaryColor: Colors.red,
              glowColor: Colors.red,
            ),
            CustomBall(
              id: 'b',
              name: 'B',
              primaryColor: Colors.blue,
              glowColor: Colors.blue,
            ),
          ],
          arenaRadius: 240,
          seed: 1,
          layoutRotation: 0,
          lookAhead: false,
          mode: MatchMode.arsenal,
          skillLibrary: SkillLibrary.defaults.withDefinition(
            custom,
            PowerUpConfig.defaults,
          ),
        );
        final ball = match.state.balls.first..position = const Offset(256, 256);
        Future<int> pixels(String skillId) async {
          ball.equipWeapon(kind, skillId: skillId, dualWield: false);
          final recorder = ui.PictureRecorder();
          PowerUpPainter.paintBallEffects(
            Canvas(recorder),
            ball,
            useWeaponSprite: (_, _) => false,
            weaponDisplayScale: (kind, slot) =>
                match.powerUps!.weaponDisplayScale(kind, ball: ball),
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(512, 512);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          var count = 0;
          for (var i = 3; i < data!.lengthInBytes; i += 4) {
            if (data.getUint8(i) > 0) count++;
          }
          image.dispose();
          picture.dispose();
          return count;
        }

        final small = await tester.runAsync(
          () => pixels('builtin.${kind.name}'),
        );
        final large = await tester.runAsync(() => pixels(custom.id));
        expect(large!, greaterThan(small! * 1.5), reason: kind.name);
      }
    },
  );
}
