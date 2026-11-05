import 'dart:ui';

import '../../../core/sprites/facing_offset.dart';

/// A saved, aim-local emitter placement. It contains no weapon-specific values.
/// Resolve it against the current owner position so sustained attacks follow
/// their caster. Drawing and collision queries must use the same resolved point.
class AttackEmitter {
  const AttackEmitter({this.forward, this.sideways = 0, this.mirror = true});

  final double? forward;
  final double sideways;
  final bool mirror;
  bool get isCustom => forward != null;

  Offset resolve(
    Offset owner,
    double radius,
    Offset direction, {
    double automaticForward = 0,
  }) =>
      owner +
      facingOffset(
        direction,
        radius * (forward ?? automaticForward),
        radius * (isCustom ? sideways : 0),
        mirror: mirror,
      );
}
