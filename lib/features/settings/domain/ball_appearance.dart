enum HpBarSize {
  small('Small', 1),
  medium('Medium', 1.35),
  large('Large', 1.7);

  const HpBarSize(this.label, this.scale);
  final String label;
  final double scale;
}

enum BallHandStyle {
  gloves('Gloves'),
  circles('Simple circles'),
  mittens('Mittens');

  const BallHandStyle(this.label);
  final String label;
}

/// Cosmetic settings shared by the live arena, admin tester and video painter.
/// No values in this model affect collision shapes, damage or random draws.
class BallAppearance {
  const BallAppearance({
    this.hpBarSize = HpBarSize.small,
    this.handScale = 1,
    this.handStyle = BallHandStyle.gloves,
    this.expressiveFaces = true,
    this.eyeScale = 1,
    this.mouthOffset = 0,
    this.glowColorValue,
  });

  static const defaults = BallAppearance();
  final HpBarSize hpBarSize;
  final double handScale;
  final BallHandStyle handStyle;
  final bool expressiveFaces;
  final double eyeScale;
  final double mouthOffset;
  /// Null follows each ball's own glow color.
  final int? glowColorValue;

  BallAppearance copyWith({
    HpBarSize? hpBarSize,
    double? handScale,
    BallHandStyle? handStyle,
    bool? expressiveFaces,
    double? eyeScale,
    double? mouthOffset,
    int? glowColorValue,
    bool resetGlowColor = false,
  }) => BallAppearance(
    hpBarSize: hpBarSize ?? this.hpBarSize,
    handScale: handScale ?? this.handScale,
    handStyle: handStyle ?? this.handStyle,
    expressiveFaces: expressiveFaces ?? this.expressiveFaces,
    eyeScale: eyeScale ?? this.eyeScale,
    mouthOffset: mouthOffset ?? this.mouthOffset,
    glowColorValue: resetGlowColor ? null : (glowColorValue ?? this.glowColorValue),
  );

  BallAppearance validated() => copyWith(
    handScale: handScale.isFinite ? handScale.clamp(.5, 2) : 1,
    eyeScale: eyeScale.isFinite ? eyeScale.clamp(.5, 1.5) : 1,
    mouthOffset: mouthOffset.isFinite ? mouthOffset.clamp(-.25, .25) : 0,
  );

  Map<String, Object?> toJson() => {
    'hp_bar_size': hpBarSize.name,
    'hand_scale': handScale,
    'hand_style': handStyle.name,
    'expressive_faces': expressiveFaces,
    'eye_scale': eyeScale,
    'mouth_offset': mouthOffset,
    'glow_color': glowColorValue,
  };

  factory BallAppearance.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    return BallAppearance(
      hpBarSize:
          HpBarSize.values
              .where((v) => v.name == raw['hp_bar_size'])
              .firstOrNull ??
          HpBarSize.small,
      handStyle:
          BallHandStyle.values
              .where((v) => v.name == raw['hand_style'])
              .firstOrNull ??
          BallHandStyle.gloves,
      handScale: raw['hand_scale'] is num
          ? (raw['hand_scale'] as num).toDouble()
          : 1,
      eyeScale: raw['eye_scale'] is num ? (raw['eye_scale'] as num).toDouble() : 1,
      mouthOffset: raw['mouth_offset'] is num ? (raw['mouth_offset'] as num).toDouble() : 0,
      glowColorValue: raw['glow_color'] is int ? raw['glow_color'] as int : null,
      expressiveFaces: raw['expressive_faces'] is bool
          ? raw['expressive_faces'] as bool
          : true,
    ).validated();
  }

  @override
  bool operator ==(Object other) =>
      other is BallAppearance &&
      other.hpBarSize == hpBarSize &&
      other.handScale == handScale &&
      other.handStyle == handStyle &&
      other.expressiveFaces == expressiveFaces &&
      other.eyeScale == eyeScale &&
      other.mouthOffset == mouthOffset &&
      other.glowColorValue == glowColorValue;
  @override
  int get hashCode =>
      Object.hash(hpBarSize, handScale, handStyle, expressiveFaces, eyeScale, mouthOffset, glowColorValue);
}
