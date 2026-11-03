import '../../../core/sprites/facing_offset.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../../core/sprites/sprite_registry.dart';
import '../domain/skill_visual_effect.dart';

/// Shared playback/placement for arena, demo, cinematic and export painters.
/// Callers own tint layers, preserving existing art tint behavior.
class SkillEffectRenderer {
  static int? _budget;
  static T withBudget<T>(int limit, T Function() body) {
    final old = _budget;
    _budget = limit;
    try {
      return body();
    } finally {
      _budget = old;
    }
  }

  static bool takeVisual() {
    if (_budget == null) return true;
    if (_budget! <= 0) return false;
    _budget = _budget! - 1;
    return true;
  }

  /// Safe, bounded playback progress shared by all legacy and Visual Events
  /// render paths. Effects may be queried during creation with zero steps,
  /// or after expiry while a painter is finishing its frame.
  static double progress(int age, int duration) {
    final safeAge = age < 0 ? 0 : age;
    final safeDuration = duration < 1 ? 1 : duration;
    return (safeAge / safeDuration).clamp(0.0, 1.0);
  }

  static double remaining(int age, int duration) =>
      1.0 - progress(age, duration);

  /// Natural playback is measured in native sprite steps, independent of
  /// the gameplay lifetime. Zero-frame/unregistered sprites are never sent
  /// through a divide-by-zero or non-finite frame progress calculation.
  static double naturalProgress(int age, int frames, int stepsPerFrame) {
    if (frames <= 0 || stepsPerFrame <= 0) return 0;
    final safeAge = age < 0 ? 0 : age;
    return (safeAge / (frames * stepsPerFrame)).clamp(0.0, 1.0);
  }

  /// A faded effect cannot amplify opacity or pass an invalid alpha to the
  /// image painter, even when an animation is sampled outside its lifetime.
  static double boundedOpacity(double opacity, double fade) {
    if (!opacity.isFinite || !fade.isFinite) return 0;
    return (opacity.clamp(0.0, 1.0) * fade.clamp(0.0, 1.0))
        .clamp(0.0, 1.0);
  }

  static Image? frame(ResolvedSkillEffect effect, int age, int duration) {
    // A zero-duration preview is valid while editing. Clamp its denominator
    // rather than letting NaN/Infinity reach the sprite frame resolver.
    final safeAge = age < 0 ? 0 : age;
    if (effect.playback == EffectPlayback.loop) {
      return SpriteRegistry.frameAt(effect.spriteId, safeAge);
    }
    if (effect.playback == EffectPlayback.holdLast ||
        effect.playback == EffectPlayback.natural) {
      final frames = SpriteRegistry.frameCount(effect.spriteId);
      return SpriteRegistry.frameAtProgress(
        effect.spriteId,
        naturalProgress(
          safeAge, frames, SpriteRegistry.stepsPerFrame(effect.spriteId),
        ),
      );
    }
    return SpriteRegistry.frameAtProgress(
      effect.spriteId,
      progress(safeAge, duration),
    );
  }

  /// Non-finite direction values must not reach canvas transforms.
  static Offset _safeDirection(Offset direction) {
    if (!direction.dx.isFinite || !direction.dy.isFinite) {
      return const Offset(1, 0);
    }
    final length = direction.distance;
    return length.isFinite && length > 0
        ? direction / length
        : const Offset(1, 0);
  }

  static Offset attachment(
    ResolvedSkillEffect effect,
    SkillVisualRole role,
    Offset point, {
    Offset? owner,
    Offset? target,
    Offset direction = const Offset(1, 0),
    double radius = 1,
  }) {
    final unit = _safeDirection(direction);
    // Malformed saved artwork may carry non-finite anchors or radius. Keep
    // attachment resolution finite so both legacy and Visual Events callers
    // receive the same deterministic placement, even before paint-time checks.
    Offset safePoint(Offset? candidate, Offset fallback) {
      if (candidate == null ||
          !candidate.dx.isFinite || !candidate.dy.isFinite) {
            return fallback;
          }
      return candidate;
    }
    final anchor = safePoint(point, Offset.zero);
    final safeOwner = safePoint(owner, anchor);
    final safeTarget = safePoint(target, anchor);
    // Reject huge radii before adding the hand offset: finite arithmetic
    // can still yield a nonsensical, effectively unrenderable coordinate.
    final safeRadius = radius.isFinite && radius > 0 && radius <= 1e6
        ? radius : 0.0;
    final place = effect.attachment == EffectAttachment.automatic
        ? switch (role) {
            SkillVisualRole.casting ||
            SkillVisualRole.ownerStatus ||
            SkillVisualRole.discard => EffectAttachment.owner,
            SkillVisualRole.targetStatus ||
            SkillVisualRole.block ||
            SkillVisualRole.breakage => EffectAttachment.target,
            SkillVisualRole.muzzle => EffectAttachment.hand,
            SkillVisualRole.trail => EffectAttachment.projectile,
            _ => EffectAttachment.impact,
          }
        : effect.attachment;
    final resolved = switch (place) {
      EffectAttachment.owner => safeOwner,
      EffectAttachment.hand => radius > 0 && safeRadius == 0
          ? safeOwner : safeOwner + unit * safeRadius * 1.1,
      EffectAttachment.target => safeTarget,
      _ => anchor,
    };
    return resolved.dx.isFinite && resolved.dy.isFinite ? resolved : safeOwner;
  }

  static bool paint(
    Canvas canvas,
    ResolvedSkillEffect effect,
    Offset center,
    double half,
    int age,
    int duration, {
    double fade = 1,
    bool essential = false,
    Offset direction = const Offset(1, 0),
    double? unitRadius,
  }) {
    final image = frame(effect, age, duration);
    if (image == null) return false;
    // Do not suppress legacy fallback art or consume the budget for a
    // Visual Event whose geometry cannot actually be rendered.
    if (!_drawable(effect, center, half, direction, unitRadius)) return false;
    if (!essential && !takeVisual()) return true;
    paintImage(canvas, effect, image, center, half,
        fade: fade, direction: direction, unitRadius: unitRadius);
    return true;
  }

  static bool _drawable(ResolvedSkillEffect effect, Offset center, double half,
      Offset direction, double? unitRadius) {
    final size = half * 2 * effect.scale;
    if (!size.isFinite || size <= 0 ||
        !center.dx.isFinite || !center.dy.isFinite) {
      return false;
    }
    final radius = unitRadius ?? half;
    if (!radius.isFinite) return false;
    final unit = _safeDirection(direction);
    final offset = facingOffset(unit, effect.offsetX * radius,
        effect.offsetY * radius,
        mirror: effect.facing != EffectFacing.direction);
    final mirrored = effect.facing == EffectFacing.mirror && unit.dx < 0;
    final angle = (effect.facing == EffectFacing.direction
        ? math.atan2(unit.dy, unit.dx) : 0) +
        effect.rotationDegrees * math.pi / 180 * (mirrored ? -1 : 1);
    return offset.dx.isFinite && offset.dy.isFinite && angle.isFinite &&
        (center.dx + offset.dx).isFinite &&
        (center.dy + offset.dy).isFinite;
  }

  /// Draw an already-resolved sprite frame using exactly the same placement,
  /// facing, mirroring, rotation and offsets as Visual Events playback.
  /// Fallback callers own the visual budget and tint layer.
  static void paintImage(
    Canvas canvas,
    ResolvedSkillEffect effect,
    Image image,
    Offset center,
    double half, {
    double fade = 1,
    Offset direction = const Offset(1, 0),
    double? unitRadius,
  }) {
    if (!_drawable(effect, center, half, direction, unitRadius)) return;
    final size = half * 2 * effect.scale;
    final unit = _safeDirection(direction);
    final radius = unitRadius ?? half;
    if (!radius.isFinite) return;
    final offset = facingOffset(
      unit,
      effect.offsetX * radius,
      effect.offsetY * radius,
      mirror: effect.facing != EffectFacing.direction,
    );
    final mirrored = effect.facing == EffectFacing.mirror && unit.dx < 0;
    final angle =
        (effect.facing == EffectFacing.direction
            ? math.atan2(unit.dy, unit.dx)
            : 0) +
        effect.rotationDegrees * math.pi / 180 * (mirrored ? -1 : 1);
    if (!offset.dx.isFinite || !offset.dy.isFinite || !angle.isFinite) return;
    canvas.save();
    canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
    canvas.rotate(angle);
    if (mirrored) canvas.scale(-1, 1);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      SpriteRegistry.imageRect(
        image,
        Offset.zero,
        size,
        size,
        SpriteRegistry.anchor(effect.spriteId),
      ),
      SpriteRegistry.imagePaint(image, opacity: boundedOpacity(effect.opacity, fade)),
    );
    canvas.restore();
  }
}
