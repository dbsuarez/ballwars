import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Number of discrete anchor slots around the rim (2 degrees each).
const int kRimSlotCount = 180;

/// One line owned by a ball: anchored to a fixed rim slot at one end and
/// attached to the owner's center at the other. A line is cut (permanently
/// removed, freeing its slot) when an opponent's body crosses it.
class FanLine {
  final String ownerBallId;
  final int slotIndex;
  final double rimAngle; // Fixed rim angle of the slot, in radians
  bool isActive;
  Offset startPoint; // Rim anchor; follows a shrinking arena.
  Offset endPoint; // Owner's center, updated every step

  FanLine({
    required this.ownerBallId,
    required this.slotIndex,
    required this.rimAngle,
    required this.startPoint,
    required this.endPoint,
    this.isActive = true,
  });

  /// Computes the rim point for this line's angle.
  Offset rimPoint(double arenaRadius) => Offset(
    math.cos(rimAngle) * arenaRadius,
    math.sin(rimAngle) * arenaRadius,
  );
}
