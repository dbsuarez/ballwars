import 'dart:typed_data';
import 'package:flutter/material.dart';

class CustomBall {
  final String id;
  final String name;
  final Uint8List? imageBytes;
  final String? assetPath;
  final Color primaryColor;
  final Color glowColor;
  final double baseSpeed;
  final double mass;

  static const double defaultBaseSpeed = 320.0;

  const CustomBall({
    required this.id,
    required this.name,
    this.imageBytes,
    this.assetPath,
    required this.primaryColor,
    required this.glowColor,
    this.baseSpeed = defaultBaseSpeed,
    this.mass = 1.0,
  });

  CustomBall copyWith({
    String? name,
    Uint8List? imageBytes,
    String? assetPath,
    Color? primaryColor,
    Color? glowColor,
    double? baseSpeed,
    double? mass,
  }) {
    return CustomBall(
      id: id,
      name: name ?? this.name,
      imageBytes: imageBytes ?? this.imageBytes,
      assetPath: assetPath ?? this.assetPath,
      primaryColor: primaryColor ?? this.primaryColor,
      glowColor: glowColor ?? this.glowColor,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      mass: mass ?? this.mass,
    );
  }
}
