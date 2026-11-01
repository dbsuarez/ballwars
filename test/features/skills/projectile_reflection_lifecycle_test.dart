import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/arena_simulation/domain/simulation_ball.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';

SimulationBall ball(String id) => SimulationBall(
  config: CustomBall(
    id: id,
    name: id,
    primaryColor: const Color(0xFFFFFFFF),
    glowColor: const Color(0xFFFFFFFF),
  ),
  position: const Offset(10, 20),
  velocity: Offset.zero,
  radius: 8,
  lineCount: 0,
);

void main() {
  test('reflection transfers damage ownership and resets hit history', () {
    final attacker = ball('attacker');
    final reflector = ball('reflector');
    final other = ball('other');
    final shot = Projectile(
      owner: attacker,
      kind: PowerUpKind.ricochetDisc,
      position: Offset.zero,
      velocity: const Offset(2, 0),
      target: other,
    );
    shot.hitTargets.add(other);
    shot.transferOwnership(reflector, returnsToOrigin: false);
    expect(shot.owner, same(reflector));
    expect(shot.target, same(attacker));
    expect(shot.hitTargets, {reflector});
  });

  test('reflected returning projectile no longer homes to old launch point', () {
    final attacker = ball('attacker');
    final reflector = ball('reflector');
    final shot = Projectile(
      owner: attacker,
      kind: PowerUpKind.ricochetDisc,
      position: Offset.zero,
      velocity: const Offset(2, 0),
      returnTo: const Offset(500, 500),
      returning: true,
    );
    shot.transferOwnership(reflector, returnsToOrigin: true);
    expect(shot.returnTo, isNull);
    expect(shot.returning, isFalse);
    expect(shot.owner, same(reflector));
  });

  test('non-returning reflection retains its flight state', () {
    final shot = Projectile(
      owner: ball('first'),
      kind: PowerUpKind.ricochetDisc,
      position: Offset.zero,
      velocity: const Offset(2, 0),
      returnTo: const Offset(3, 4),
      returning: true,
    );
    shot.transferOwnership(ball('second'), returnsToOrigin: false);
    expect(shot.returnTo, const Offset(3, 4));
    expect(shot.returning, isTrue);
  });
}
