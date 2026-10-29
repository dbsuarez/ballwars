import 'dart:ui';
import 'dart:math' as math;
import '../../../core/sprites/sprite_registry.dart';
import '../domain/skill_visual_effect.dart';

/// Shared playback/placement for arena, demo, cinematic and export painters.
/// Callers own tint layers, preserving existing art tint behavior.
class SkillEffectRenderer {
  static Image? frame(ResolvedSkillEffect effect, int age, int duration) {
    if (effect.playback == EffectPlayback.loop) {
      return SpriteRegistry.frameAt(effect.spriteId, age);
    }
    if (effect.playback == EffectPlayback.holdLast ||
        effect.playback == EffectPlayback.natural) {
      final frames = SpriteRegistry.frameCount(effect.spriteId);
      final steps = frames * SpriteRegistry.stepsPerFrame(effect.spriteId);
      return SpriteRegistry.frameAtProgress(
        effect.spriteId,
        steps == 0 ? 0 : age / steps,
      );
    }
    return SpriteRegistry.frameAtProgress(effect.spriteId, age / duration);
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
    final unit = direction.distance > 0
        ? direction / direction.distance
        : const Offset(1, 0);
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
    return switch (place) {
      EffectAttachment.owner => owner ?? point,
      EffectAttachment.hand => (owner ?? point) + unit * radius * 1.1,
      EffectAttachment.target => target ?? point,
      _ => point,
    };
  }

  static bool paint(
    Canvas canvas,
    ResolvedSkillEffect effect,
    Offset center,
    double half,
    int age,
    int duration, {
    double fade = 1,
    Offset direction = const Offset(1, 0),
    double? unitRadius,
  }) {
    final image = frame(effect, age, duration);
    if (image == null) return false;
    final size = half * 2 * effect.scale;
    final unit = direction.distance > 0
        ? direction / direction.distance
        : const Offset(1, 0);
    final radius = unitRadius ?? half;
    final offset =
        unit * (effect.offsetX * radius) +
        Offset(-unit.dy, unit.dx) * (effect.offsetY * radius);
    final mirrored = effect.facing == EffectFacing.mirror && unit.dx < 0;
    final angle =
        (effect.facing == EffectFacing.direction
            ? math.atan2(unit.dy, unit.dx)
            : 0) +
        effect.rotationDegrees * math.pi / 180 * (mirrored ? -1 : 1);
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
      SpriteRegistry.imagePaint(image, opacity: effect.opacity * fade),
    );
    canvas.restore();
    return true;
  }
}
