import 'dart:ui';

/// Non-destructive map-local adjustments; never modifies the shared image.
class ArenaBackgroundStyle {
  const ArenaBackgroundStyle({
    this.zoom = 1,
    this.x = .5,
    this.y = .5,
    this.dim = 0,
  });
  final double zoom, x, y, dim;
  bool get isDefault => zoom == 1 && x == .5 && y == .5 && dim == 0;
  ArenaBackgroundStyle copyWith({
    double? zoom,
    double? x,
    double? y,
    double? dim,
  }) => ArenaBackgroundStyle(
    zoom: zoom ?? this.zoom,
    x: x ?? this.x,
    y: y ?? this.y,
    dim: dim ?? this.dim,
  );
  Rect crop(Size source) {
    final side = source.shortestSide / zoom.clamp(1, 4);
    return Rect.fromLTWH(
      (source.width - side) * x.clamp(0, 1),
      (source.height - side) * y.clamp(0, 1),
      side,
      side,
    );
  }

  Map<String, double> toJson() => {'zoom': zoom, 'x': x, 'y': y, 'dim': dim};
  static ArenaBackgroundStyle fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid background adjustments.');
    }
    double number(String key, double min, double max) {
      final n = value[key];
      if (n is! num || !n.isFinite || n < min || n > max) {
        throw FormatException('Background $key must be between $min and $max.');
      }
      return n.toDouble();
    }

    return ArenaBackgroundStyle(
      zoom: number('zoom', 1, 4),
      x: number('x', 0, 1),
      y: number('y', 0, 1),
      dim: number('dim', 0, 1),
    );
  }
}
