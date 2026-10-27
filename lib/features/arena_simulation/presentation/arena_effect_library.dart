import 'dart:ui' as ui;

import '../../../core/sprites/sprite_registry.dart';

enum ArenaEffectPlayback { once, loop }

enum ArenaEffectKind {
  flame,
  campfire,
  explosion,
  smoke,
  lightning,
  water,
  portal,
  iceImpact,
  slash,
  blood,
  speedStreak,
  magneticField,
  timeBubble,
  armorImpact,
  stickyGoo,
  maximumPower,
}

class ArenaEffectDefinition {
  const ArenaEffectDefinition({
    this.id,
    this.playback = ArenaEffectPlayback.once,
    this.tintable = false,
  });

  /// Atlas sprite id: `anim.<name>` for an animation, `effect.<name>` for a
  /// single image; null while the effect has no artwork.
  final String? id;
  final ArenaEffectPlayback playback;
  final bool tintable;

  /// Frames in the atlas (0 before [SpriteRegistry.load] or without art).
  int get frames => id == null ? 0 : SpriteRegistry.frameCount(id!);

  /// Simulation steps per frame, from the atlas manifest.
  int get stepsPerFrame => id == null ? 1 : SpriteRegistry.stepsPerFrame(id!);
}

/// Shared artwork and playback metadata for gameplay and finishers. Frame
/// counts and timing come from the atlas manifests.
/// Smoke and water are reserved for dedicated future sheets.
class ArenaEffectLibrary {
  ArenaEffectLibrary._();

  static const definitions = <ArenaEffectKind, ArenaEffectDefinition>{
    ArenaEffectKind.flame: ArenaEffectDefinition(
      id: 'anim.flame',
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.campfire: ArenaEffectDefinition(
      id: 'anim.campfire',
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.explosion: ArenaEffectDefinition(id: 'anim.explosion'),
    ArenaEffectKind.smoke: ArenaEffectDefinition(tintable: true),
    ArenaEffectKind.lightning: ArenaEffectDefinition(id: 'anim.lightning'),
    ArenaEffectKind.water: ArenaEffectDefinition(tintable: true),
    ArenaEffectKind.portal: ArenaEffectDefinition(
      id: 'anim.portal',
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.iceImpact: ArenaEffectDefinition(id: 'anim.iceImpact'),
    ArenaEffectKind.slash: ArenaEffectDefinition(id: 'anim.slash'),
    ArenaEffectKind.blood: ArenaEffectDefinition(
      id: 'anim.blood',
      tintable: true,
    ),
    ArenaEffectKind.speedStreak: ArenaEffectDefinition(
      id: 'effect.speedStreak',
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.magneticField: ArenaEffectDefinition(
      id: 'effect.magneticField',
      playback: ArenaEffectPlayback.loop,
      tintable: true,
    ),
    ArenaEffectKind.timeBubble: ArenaEffectDefinition(
      id: 'effect.timeBubble',
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.armorImpact: ArenaEffectDefinition(
      id: 'effect.goldenArmorHit',
    ),
    ArenaEffectKind.stickyGoo: ArenaEffectDefinition(
      id: 'effect.stickyGoo',
      playback: ArenaEffectPlayback.loop,
      tintable: true,
    ),
    ArenaEffectKind.maximumPower: ArenaEffectDefinition(
      id: 'anim.maximumPower',
      playback: ArenaEffectPlayback.loop,
    ),
  };

  /// The frame of [kind] at simulation [step]: looping effects wrap, the
  /// others hold their last frame. Null before the atlas loads or without art.
  static ui.Image? frame(ArenaEffectKind kind, int step) {
    final definition = definitions[kind]!;
    final id = definition.id;
    if (id == null) return null;
    final frames = definition.frames;
    if (frames == 0) return null;
    var index = step ~/ definition.stepsPerFrame;
    if (definition.playback == ArenaEffectPlayback.loop) {
      index %= frames;
    } else {
      index = index.clamp(0, frames - 1);
    }
    return SpriteRegistry.frame(id, index);
  }
}
