import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import 'fan_line.dart';

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

  SimulationBall({
    required this.config,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.lineCount,
    this.cachedUiImage,
  });
}
