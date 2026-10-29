import 'dart:ui';
import '../../../core/sprites/sprite_registry.dart';
import '../domain/skill_visual_effect.dart';

/// Shared playback/placement for arena, demo, cinematic and export painters.
/// Callers own tint layers, preserving existing art tint behavior.
class SkillEffectRenderer {
  static Image? frame(ResolvedSkillEffect effect, int age, int duration) {
    if (effect.playback == EffectPlayback.loop) {
      return SpriteRegistry.frameAt(effect.spriteId, age);
    }
    if (effect.playback == EffectPlayback.holdLast) {
      final frames = SpriteRegistry.frameCount(effect.spriteId);
      final steps = frames * SpriteRegistry.stepsPerFrame(effect.spriteId);
      return SpriteRegistry.frameAtProgress(
        effect.spriteId,
        steps == 0 ? 0 : age / steps,
      );
    }
    return SpriteRegistry.frameAtProgress(effect.spriteId, age / duration);
  }

  static bool paint(
    Canvas canvas,
    ResolvedSkillEffect effect,
    Offset center,
    double half,
    int age,
    int duration, {
    double fade = 1,
  }) {
    final image = frame(effect, age, duration);
    if (image == null) return false;
    final size = half * 2 * effect.scale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      SpriteRegistry.imageRect(
        image,
        center,
        size,
        size,
        SpriteRegistry.anchor(effect.spriteId),
      ),
      SpriteRegistry.imagePaint(image, opacity: effect.opacity * fade),
    );
    return true;
  }
}
