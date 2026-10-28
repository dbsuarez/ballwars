import 'dart:typed_data';
import 'package:flutter/material.dart';

/// How a ball's image sits on the ball.
enum BallImageStyle {
  /// The image fills the whole ball (photos, flags).
  cover,

  /// A full-color logo, fitted inside a white ball.
  logo,
}

/// A ball's gender, picked in the ball editor. Male and female balls always
/// get hair from their own style pool (see BallHairPainter); none keeps the
/// old behavior (hair only with "Random hairstyles").
enum BallGender { none, male, female }

class CustomBall {
  final String id;
  final String name;
  final Uint8List? imageBytes;
  final String? assetPath;

  /// Image hosted online (PNG/JPEG or SVG), e.g. a built-in pack logo.
  final String? imageUrl;
  final BallImageStyle imageStyle;
  final Color primaryColor;
  final Color glowColor;
  final double baseSpeed;
  final double mass;

  /// Cosmetic: picks the ball's hair pool. Never changes the match.
  final BallGender gender;

  static const double defaultBaseSpeed = 320.0;

  const CustomBall({
    required this.id,
    required this.name,
    this.imageBytes,
    this.assetPath,
    this.imageUrl,
    this.imageStyle = BallImageStyle.cover,
    required this.primaryColor,
    required this.glowColor,
    this.baseSpeed = defaultBaseSpeed,
    this.mass = 1.0,
    this.gender = BallGender.none,
  });

  bool get hasImage => imageBytes != null || imageUrl != null;

  CustomBall copyWith({
    String? name,
    Uint8List? imageBytes,
    String? assetPath,
    String? imageUrl,
    BallImageStyle? imageStyle,
    Color? primaryColor,
    Color? glowColor,
    double? baseSpeed,
    double? mass,
    BallGender? gender,
  }) {
    return CustomBall(
      id: id,
      name: name ?? this.name,
      imageBytes: imageBytes ?? this.imageBytes,
      assetPath: assetPath ?? this.assetPath,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStyle: imageStyle ?? this.imageStyle,
      primaryColor: primaryColor ?? this.primaryColor,
      glowColor: glowColor ?? this.glowColor,
      baseSpeed: baseSpeed ?? this.baseSpeed,
      mass: mass ?? this.mass,
      gender: gender ?? this.gender,
    );
  }
}
