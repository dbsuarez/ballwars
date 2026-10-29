import 'dart:ui';

/// Aim-local placement with a mirrored left-facing frame. A sideways offset
/// above the ball remains above it when the facing changes horizontally.
/// Explicit full-rotation artwork can opt out of mirroring.
Offset facingOffset(
  Offset direction,
  double forward,
  double sideways, {
  bool mirror = true,
}) {
  final unit = direction.distance > 0
      ? direction / direction.distance
      : const Offset(1, 0);
  final sideSign = mirror && unit.dx < 0 ? -1.0 : 1.0;
  return unit * forward + Offset(-unit.dy, unit.dx) * sideways * sideSign;
}
