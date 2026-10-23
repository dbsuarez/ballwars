import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import 'fan_line.dart';
import 'power_up.dart';

class SimulationBall {
  final CustomBall config;
  Offset position;
  Offset velocity;
  double radius;
  int lineCount;
  ui.Image? cachedUiImage;
  bool isEliminated = false;
  double rotation = 0.0; // Visual spin from collisions
  double angularVelocity = 0.0; // Angular velocity from collisions

  // Lines from this ball to the rim slots it owns
  final List<FanLine> fanLines = [];

  // Power-up state (Arsenal and All-Out modes; unused in Threads)
  /// Life points in Arsenal mode (set to `PowerUpTuning.arenaLife` there).
  double life = 0;

  /// The power-up carried, waiting to be used.
  PowerUpKind? held;
  int speedLeft = 0;
  int frozenLeft = 0;
  int ghostLeft = 0;

  /// All-Out sword sweep: steps left of the wider cutting reach after picking up a knife.
  int sweepLeft = 0;

  /// Threads held at the start of the match (All-Out hearts show the share left).
  int startLines = 0;

  /// Steps left of the wince on a "Faces" ball after a hit or a lost thread (cosmetic only).
  int hurtFlashLeft = 0;
  bool magnetPending = false;

  /// Direction a held shield faces, in radians: it turns toward the biggest threat (see
  /// `PowerUpSystem`). Blocking works from every side; this only shows where it braces.
  double shieldAngle = 0;

  /// Steps left of aiming before a gun fires at [aimTarget].
  int aimLeft = 0;
  SimulationBall? aimTarget;

  /// Gatling rounds still to fire.
  int burstLeft = 0;

  bool get isGhost => ghostLeft > 0;

  SimulationBall({
    required this.config,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.lineCount,
    this.cachedUiImage,
  });
}
