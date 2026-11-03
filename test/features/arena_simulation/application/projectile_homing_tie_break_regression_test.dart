
import 'package:ballwars/features/arena_simulation/application/match_simulation_controller.dart';
import 'package:ballwars/features/arena_simulation/domain/power_up.dart';
import 'package:ballwars/features/ball_management/domain/custom_ball.dart';
import 'package:ballwars/features/match_setup/domain/match_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchSimulationController arena() {
    final match = MatchSimulationController(const [
      CustomBall(id: 'owner', name: 'Owner', primaryColor: Colors.red, glowColor: Colors.pink),
      CustomBall(id: 'z', name: 'Z', primaryColor: Colors.blue, glowColor: Colors.cyan),
      CustomBall(id: 'a', name: 'A', primaryColor: Colors.green, glowColor: Colors.lime),
    ], arenaRadius: 260, seed: 91, mode: MatchMode.arsenal, lookAhead: false);
    match.powerUps!.automaticSpawning = false;
    return match;
  }

  test('equidistant homing targets use stable contestant ID', () {
    final match = arena();
    final [owner, z, a] = match.state.balls;
    owner.position = const Offset(-200, 0);
    z.position = const Offset(100, 100);
    a.position = const Offset(100, -100);
    final shot = Projectile(owner: owner, kind: PowerUpKind.ricochetDisc,
      position: const Offset(0, 0), velocity: const Offset(120, 0), homing: true);
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.step();
    expect(shot.target, same(a));
  });

  test('strictly nearer homing target wins regardless of ID', () {
    final match = arena();
    final [owner, z, a] = match.state.balls;
    owner.position = const Offset(-200, 0);
    z.position = const Offset(70, 0);
    a.position = const Offset(120, 0);
    final shot = Projectile(owner: owner, kind: PowerUpKind.ricochetDisc,
      position: const Offset(0, 0), velocity: const Offset(120, 0), homing: true);
    match.powerUps!.projectiles.add(shot);
    match.powerUps!.step();
    expect(shot.target, same(z));
  });
}
