import 'dart:ui' as ui;

import 'power_up_sprites.dart';

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
    this.animation,
    this.sprite,
    this.frames = 1,
    this.stepsPerFrame = 3,
    this.playback = ArenaEffectPlayback.once,
    this.tintable = false,
  });

  final AnimatedEffect? animation;
  final EffectSprite? sprite;
  final int frames;
  final int stepsPerFrame;
  final ArenaEffectPlayback playback;
  final bool tintable;
}

/// Shared artwork and playback metadata for gameplay and finishers.
/// Smoke and water are reserved for dedicated future sheets.
class ArenaEffectLibrary {
  ArenaEffectLibrary._();

  static const definitions = <ArenaEffectKind, ArenaEffectDefinition>{
    ArenaEffectKind.flame: ArenaEffectDefinition(
      animation: AnimatedEffect.flame,
      frames: 4,
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.campfire: ArenaEffectDefinition(
      animation: AnimatedEffect.campfire,
      frames: 4,
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.explosion: ArenaEffectDefinition(
      animation: AnimatedEffect.explosion,
      frames: 4,
      stepsPerFrame: 2,
    ),
    ArenaEffectKind.smoke: ArenaEffectDefinition(tintable: true),
    ArenaEffectKind.lightning: ArenaEffectDefinition(
      animation: AnimatedEffect.lightning,
      frames: 8,
      stepsPerFrame: 1,
    ),
    ArenaEffectKind.water: ArenaEffectDefinition(tintable: true),
    ArenaEffectKind.portal: ArenaEffectDefinition(
      animation: AnimatedEffect.portal,
      frames: 4,
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.iceImpact: ArenaEffectDefinition(
      animation: AnimatedEffect.iceImpact,
      frames: 4,
      stepsPerFrame: 2,
    ),
    ArenaEffectKind.slash: ArenaEffectDefinition(
      animation: AnimatedEffect.slash,
      frames: 4,
      stepsPerFrame: 2,
    ),
    ArenaEffectKind.blood: ArenaEffectDefinition(
      animation: AnimatedEffect.blood,
      frames: 4,
      stepsPerFrame: 2,
      tintable: true,
    ),
    ArenaEffectKind.speedStreak: ArenaEffectDefinition(
      sprite: EffectSprite.speedStreak,
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.magneticField: ArenaEffectDefinition(
      sprite: EffectSprite.magneticField,
      playback: ArenaEffectPlayback.loop,
      tintable: true,
    ),
    ArenaEffectKind.timeBubble: ArenaEffectDefinition(
      sprite: EffectSprite.timeBubble,
      playback: ArenaEffectPlayback.loop,
    ),
    ArenaEffectKind.armorImpact: ArenaEffectDefinition(
      sprite: EffectSprite.goldenArmorHit,
    ),
    ArenaEffectKind.stickyGoo: ArenaEffectDefinition(
      sprite: EffectSprite.stickyGoo,
      playback: ArenaEffectPlayback.loop,
      tintable: true,
    ),
    ArenaEffectKind.maximumPower: ArenaEffectDefinition(
      animation: AnimatedEffect.maximumPower,
      frames: 4,
      stepsPerFrame: 3,
      playback: ArenaEffectPlayback.loop,
    ),
  };

  static ui.Image? frame(ArenaEffectKind kind, int step) {
    final definition = definitions[kind]!;
    final animation = definition.animation;
    if (animation != null) {
      var index = step ~/ definition.stepsPerFrame;
      if (definition.playback == ArenaEffectPlayback.loop) {
        index %= definition.frames;
      } else {
        index = index.clamp(0, definition.frames - 1);
      }
      return PowerUpSprites.effectFrame(animation, index);
    }
    final sprite = definition.sprite;
    return sprite == null ? null : PowerUpSprites.effect(sprite);
  }
}
