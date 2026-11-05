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
    this.mouthScale = 1,
    this.pupilFollow = 1,
    this.blinkInterval = 0,
    this.blinkDuration = .12,
    this.glowColorValue,
  });

  static const defaults = BallAppearance();
  final HpBarSize hpBarSize;
  final double handScale;
  final BallHandStyle handStyle;
  final bool expressiveFaces;
  final double eyeScale;
  final double mouthOffset;
  final double mouthScale;
  final double pupilFollow;

  /// Seconds between cosmetic blinks; zero disables blinking.
  final double blinkInterval;
  final double blinkDuration;

  /// Null follows each ball's own glow color.
  final int? glowColorValue;

  BallAppearance copyWith({
    HpBarSize? hpBarSize,
    double? handScale,
    BallHandStyle? handStyle,
    bool? expressiveFaces,
    double? eyeScale,
    double? mouthOffset,
    double? mouthScale,
    double? pupilFollow,
    double? blinkInterval,
    double? blinkDuration,
    int? glowColorValue,
    bool resetGlowColor = false,
  }) => BallAppearance(
    hpBarSize: hpBarSize ?? this.hpBarSize,
    handScale: handScale ?? this.handScale,
    handStyle: handStyle ?? this.handStyle,
    expressiveFaces: expressiveFaces ?? this.expressiveFaces,
    eyeScale: eyeScale ?? this.eyeScale,
    mouthOffset: mouthOffset ?? this.mouthOffset,
    mouthScale: mouthScale ?? this.mouthScale,
    pupilFollow: pupilFollow ?? this.pupilFollow,
    blinkInterval: blinkInterval ?? this.blinkInterval,
    blinkDuration: blinkDuration ?? this.blinkDuration,
    glowColorValue: resetGlowColor
        ? null
        : (glowColorValue ?? this.glowColorValue),
  );

  BallAppearance validated() => copyWith(
    mouthScale: mouthScale.isFinite ? mouthScale.clamp(.5, 1.5) : 1,
    pupilFollow: pupilFollow.isFinite ? pupilFollow.clamp(0, 2) : 1,
    blinkInterval: blinkInterval.isFinite
        ? (blinkInterval <= 0 ? 0 : blinkInterval.clamp(1, 10))
        : 0,
    blinkDuration: blinkDuration.isFinite ? blinkDuration.clamp(.06, .4) : .12,
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
    'mouth_scale': mouthScale,
    'pupil_follow': pupilFollow,
    'blink_interval': blinkInterval,
    'blink_duration': blinkDuration,
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
      eyeScale: raw['eye_scale'] is num
          ? (raw['eye_scale'] as num).toDouble()
          : 1,
      mouthOffset: raw['mouth_offset'] is num
          ? (raw['mouth_offset'] as num).toDouble()
          : 0,
      mouthScale: raw['mouth_scale'] is num
          ? (raw['mouth_scale'] as num).toDouble()
          : 1,
      pupilFollow: raw['pupil_follow'] is num
          ? (raw['pupil_follow'] as num).toDouble()
          : 1,
      blinkInterval: raw['blink_interval'] is num
          ? (raw['blink_interval'] as num).toDouble()
          : 0,
      blinkDuration: raw['blink_duration'] is num
          ? (raw['blink_duration'] as num).toDouble()
          : .12,
      glowColorValue: raw['glow_color'] is int
          ? raw['glow_color'] as int
          : null,
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
      other.mouthScale == mouthScale &&
      other.pupilFollow == pupilFollow &&
      other.blinkInterval == blinkInterval &&
      other.blinkDuration == blinkDuration &&
      other.glowColorValue == glowColorValue;
  @override
  int get hashCode => Object.hash(
    hpBarSize,
    handScale,
    handStyle,
    expressiveFaces,
    eyeScale,
    mouthOffset,
    glowColorValue,
    mouthScale,
    pupilFollow,
    blinkInterval,
    blinkDuration,
  );
}
