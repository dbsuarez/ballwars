import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/core/sprites/facing_offset.dart';
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/presentation/power_up_painter.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:ballwars/features/skills/domain/skill_library.dart';
import 'visual_authoring_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('left and right facing mirror x while keeping the vertical offset', () {
    for (final direction in [
      const Offset(1, 0),
      const Offset(.8, -.6),
      const Offset(.8, .6),
    ]) {
      final right = facingOffset(direction, 1.64, -.52);
      final left = facingOffset(
        Offset(-direction.dx, direction.dy),
        1.64,
        -.52,
      );
      expect(left.dx, closeTo(-right.dx, 1e-9));
      expect(left.dy, closeTo(right.dy, 1e-9));
    }
    expect(
      facingOffset(const Offset(-1, 0), 1.64, -.52, mirror: false),
      const Offset(-1.64, .52),
    );
  });

  test(
    'actual native and composed launch points mirror the same as the preview',
    () {
      for (final kind in [
        PowerUpKind.pistol,
        PowerUpKind.grenade,
        PowerUpKind.molotov,
        PowerUpKind.rocketLauncher,
      ]) {
        final skill = SkillLibrary.defaults
            .builtIn(kind, fixtures.tuning)
            .copyWith(
              projectileOriginForward: 1.64,
              projectileOriginSide: -.52,
            );
        final m = fixtures.match(skill), owner = m.state.balls.first;
        owner.position = Offset.zero;
        final right = m.powerUps!.projectileOrigin(
          owner,
          skill,
          const Offset(1, 0),
        );
        final left = m.powerUps!.projectileOrigin(
          owner,
          skill,
          const Offset(-1, 0),
        );
        expect(left.dx, closeTo(-right.dx, 1e-9));
        expect(left.dy, closeTo(right.dy, 1e-9));
        expect(left.dy, lessThan(0));
        final legacy = MatchSimulationController(
          fixtures.balls,
          arenaRadius: 180,
          mode: MatchMode.arsenal,
          seed: 1,
          lookAhead: false,
          simulationRevision: 3,
        );
        legacy.state.balls.first.position = Offset.zero;
        expect(
          legacy.powerUps!
              .projectileOrigin(
                legacy.state.balls.first,
                skill,
                const Offset(-1, 0),
              )
              .dy,
          greaterThan(0),
        );
      }
    },
  );

  test(
    'shield and weapon grips honor mirrored offsets and shield grip inset',
    () {
      final skill = SkillLibrary.defaults.builtIn(
        PowerUpKind.pistol,
        fixtures.tuning,
      );
      final m = fixtures.match(skill), ball = m.state.balls.first;
      ball.position = Offset.zero;
      for (final kind in [
        PowerUpKind.pistol,
        PowerUpKind.shield,
        PowerUpKind.sword,
      ]) {
        ball
          ..velocity = const Offset(100, 0)
          ..shieldAngle = 0;
        final right = PowerUpPainter.heldCenter(
          ball,
          weapon: kind,
          gripInset: .2,
          gripSide: -.5,
        );
        ball
          ..velocity = const Offset(-100, 0)
          ..shieldAngle = math.pi;
        final left = PowerUpPainter.heldCenter(
          ball,
          weapon: kind,
          gripInset: .2,
          gripSide: -.5,
        );
        expect(left.dx, closeTo(-right.dx, 1e-9));
        expect(left.dy, closeTo(right.dy, 1e-9));
        expect(left.dy, lessThan(0));
        expect(
          PowerUpPainter.heldFacingTransform(
            math.pi,
            -90,
            SkillHeldFacing.automatic,
            shield: kind == PowerUpKind.shield,
          ).flip,
          isTrue,
        );
      }
      ball
        ..velocity = const Offset(100, 0)
        ..shieldAngle = 0;
      expect(
        PowerUpPainter.heldCenter(
          ball,
          weapon: PowerUpKind.shield,
          gripInset: .2,
        ).dx,
        closeTo(ball.radius * .8, 1e-9),
      );
    },
  );
}
