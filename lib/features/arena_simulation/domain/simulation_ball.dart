import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';

class SimulationBall {
  final CustomBall config;
  Offset position;
  Offset velocity;
  double radius;
  int lineCount;
  ui.Image? cachedUiImage;
  bool isEliminated = false;
  Offset? threadAnchor;

  SimulationBall({
    required this.config,
    required this.position,
    required this.velocity,
    required this.radius,
    required this.lineCount,
    this.cachedUiImage,
  });
}
