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
  });

  static const defaults = BallAppearance();
  final HpBarSize hpBarSize;
  final double handScale;
  final BallHandStyle handStyle;
  final bool expressiveFaces;

  BallAppearance copyWith({
    HpBarSize? hpBarSize,
    double? handScale,
    BallHandStyle? handStyle,
    bool? expressiveFaces,
  }) => BallAppearance(
    hpBarSize: hpBarSize ?? this.hpBarSize,
    handScale: handScale ?? this.handScale,
    handStyle: handStyle ?? this.handStyle,
    expressiveFaces: expressiveFaces ?? this.expressiveFaces,
  );

  BallAppearance validated() =>
      copyWith(handScale: handScale.isFinite ? handScale.clamp(.5, 2) : 1);

  Map<String, Object> toJson() => {
    'hp_bar_size': hpBarSize.name,
    'hand_scale': handScale,
    'hand_style': handStyle.name,
    'expressive_faces': expressiveFaces,
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
      other.expressiveFaces == expressiveFaces;
  @override
  int get hashCode =>
      Object.hash(hpBarSize, handScale, handStyle, expressiveFaces);
}
