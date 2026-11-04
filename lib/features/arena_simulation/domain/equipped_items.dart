import 'power_up.dart';
import 'simulation_ball.dart';

List<PowerUpKind> equippedItems(SimulationBall ball) => [
  ...ball.equippedWeapons,
  if (ball.speedLeft > 0) PowerUpKind.speed,
  if (ball.frozenLeft > 0) PowerUpKind.freeze,
  if (ball.ghostLeft > 0) PowerUpKind.ghost,
  if (ball.magnetPending) PowerUpKind.magnet,
  if (ball.repulsorLeft > 0) PowerUpKind.repulsor,
  if (ball.timeBubbleLeft > 0) PowerUpKind.timeBubble,
  if (ball.vampireLeft > 0) PowerUpKind.vampire,
  if (ball.mirrorCharges > 0) PowerUpKind.mirror,
  if (ball.overchargeLeft > 0) PowerUpKind.overcharge,
  if (ball.gremlinShots > 0) PowerUpKind.gremlin,
  if (ball.magneticFieldLeft > 0) PowerUpKind.magneticField,
  if (ball.goldenArmorHits > 0) PowerUpKind.goldenArmor,
];
