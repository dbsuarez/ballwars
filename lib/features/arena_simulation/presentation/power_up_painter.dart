import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import 'power_up_sprites.dart';
import 'lightning_strike_painter.dart';
import 'arena_effect_library.dart';
import '../../settings/domain/app_settings.dart';
import '../../skills/presentation/skill_artwork_tint.dart';

/// Draws the power-up layer of an Arsenal / All-Out match in the arena's coordinates (center at 0, 0):
/// pulsing field power-ups, armed mines, aim lines, bullets, blasts and knife slashes ([paint]), plus the
/// per-ball looks ([paintBallEffects]: the held weapon or shield on the ball, frozen tint).
///
/// Flat style and cheap to draw (see CLAUDE.md "Painting performance"): no blur filters, icons are
/// pixel-art images ([PowerUpSprites]), bullets are one batched drawRawPoints call.
class PowerUpPainter {
  PowerUpPainter._();

  // Rate overrides: these call sites play a sprite slower than its manifest
  // `stepsPerFrame`, which ArenaEffectLibrary (finishers, goldens) uses for
  // the same sprite. Both looks are kept as they were.
  /// Campfire flames of burning zones and fire walls (manifest: 3).
  static const int _campfireStepsPerFrame = 4;

  /// Portal and swap-cannon flashes and portals on the rim (manifest: 3).
  static const int _portalStepsPerFrame = 4;

  /// Flames on a burning ball (manifest `anim.flame`: 3).
  static const int _burningFlameStepsPerFrame = 4;

  static const Map<PowerUpKind, Color> _colors = {
    PowerUpKind.pistol: Color(0xFFF2B33D),
    PowerUpKind.shotgun: Color(0xFFE8833A),
    PowerUpKind.gatling: Color(0xFFD9534F),
    PowerUpKind.knife: Color(0xFFB8C2CC),
    PowerUpKind.shield: Color(0xFF4F8EF7),
    PowerUpKind.apple: Color(0xFF3BB54A),
    PowerUpKind.speed: Color(0xFFF5E050),
    PowerUpKind.freeze: Color(0xFF7FDBFF),
    PowerUpKind.mine: Color(0xFF9A9AAE),
    PowerUpKind.magnet: Color(0xFFE0457B),
    PowerUpKind.ghost: Color(0xFFC9B8F0),
    PowerUpKind.grenade: Color(0xFF8DBF4A),
    PowerUpKind.sword: Color(0xFFE6D3A3),
    PowerUpKind.hook: Color(0xFFFF8A3D),
    PowerUpKind.ricochetDisc: Color(0xFF00D4FF),
    PowerUpKind.orbitingFlail: Color(0xFF9FA8B5),
    PowerUpKind.threadHarpoon: Color(0xFF00C9A7),
    PowerUpKind.prismLaser: Color(0xFFFF4FD8),
    PowerUpKind.swapCannon: Color(0xFF7C5CFF),
    PowerUpKind.phaseMine: Color(0xFF6D35A8),
    PowerUpKind.repulsor: Color(0xFFFF6B35),
    PowerUpKind.timeBubble: Color(0xFF58A6FF),
    PowerUpKind.vampire: Color(0xFFB1123B),
    PowerUpKind.mirror: Color(0xFFC7F5FF),
    PowerUpKind.overcharge: Color(0xFFFFD000),
    PowerUpKind.gremlin: Color(0xFF7ED957),
    PowerUpKind.magneticField: Color(0xFFB04CFF),
    PowerUpKind.portal: Color(0xFF36E1FF),
    PowerUpKind.spikeWall: Color(0xFFFF5353),
    PowerUpKind.goldenArmor: Color(0xFFFFD54F),
    PowerUpKind.bow: Color(0xFFC98A43),
    PowerUpKind.stickyGoo: Color(0xFF65E34F),
    PowerUpKind.molotov: Color(0xFFFF6A2A),
    PowerUpKind.rocketLauncher: Color(0xFF98A84B),
    PowerUpKind.omegaTendrils: Color(0xFFE21D35),
    PowerUpKind.boomerang: Color(0xFF20DDF2),
    PowerUpKind.fireWall: Color(0xFFFF6A22),
    PowerUpKind.poisonSwamp: Color(0xFF8EEA31),
    PowerUpKind.waterGun: Color(0xFF39BFFF),
    PowerUpKind.lightningStrikes: Color(0xFFFFFF66),
    PowerUpKind.earthquake: Color(0xFFD88A39),
    PowerUpKind.tornado: Color(0xFFBCEEFF),
    PowerUpKind.energyWave: Color(0xFF31DFFF),
    PowerUpKind.flamethrower: Color(0xFFFF6422),
    PowerUpKind.friedChicken: Color(0xFFFFB43B),
    PowerUpKind.sniperRifle: Color(0xFFFFC107),
    PowerUpKind.busterSword: Color(0xFFCFB6FF),
    PowerUpKind.ragingDemon: Color(0xFF8F001D),
  };

  /// The color a power-up is drawn in.
  static Color colorOf(PowerUpKind kind) => _colors[kind]!;

  /// Field power-ups, aim lines, bullets, mines, blasts and slashes. Call after the fan lines, before the
  /// balls. [showEffects] covers only the decorative blast flash; gameplay objects always draw.
  static void paint(
    Canvas canvas,
    SimulationState state,
    double arenaRadius, {
    bool showEffects = true,
    bool whitePickupBackgrounds = true,
    EffectRenderMode projectileRenderMode = EffectRenderMode.sprite,
    EffectRenderMode explosionRenderMode = EffectRenderMode.sprite,
    EffectRenderMode freezeRenderMode = EffectRenderMode.sprite,
  }) {
    final p = state.powerUps;
    if (p == null) return;
    final r = p.fieldRadius;

    if (p.ragingDemonAttacks.isNotEmpty) {
      canvas.drawCircle(
        Offset.zero,
        arenaRadius,
        Paint()..color = const Color(0xFF050006).withValues(alpha: 0.82),
      );
      for (final attack in p.ragingDemonAttacks) {
        SkillArtworkTint.begin(
          canvas,
          p.artworkTint(PowerUpKind.ragingDemon, ball: attack.owner),
        );
        try {
          final pulse = 0.65 + 0.35 * math.sin(attack.age * 1.7).abs();
          canvas.drawCircle(
            attack.target.position,
            r * (1.2 + pulse * 0.6),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(3, r * 0.22)
              ..color = const Color(0xFFFF1738).withValues(alpha: pulse),
          );
          for (var i = 0; i < 6; i++) {
            final angle = attack.age * 0.31 + i * math.pi / 3;
            final direction = Offset.fromDirection(angle);
            canvas.drawLine(
              attack.target.position - direction * r * 0.35,
              attack.target.position + direction * r * 1.45,
              Paint()
                ..strokeWidth = math.max(2, r * 0.13)
                ..color = Colors.white.withValues(alpha: pulse * 0.85),
            );
          }
        } finally {
          SkillArtworkTint.end(canvas);
        }
      }
    }

    if (p.omnislashAttacks.isNotEmpty) {
      canvas.drawCircle(
        Offset.zero,
        arenaRadius,
        Paint()..color = const Color(0xFF020818).withValues(alpha: 0.58),
      );
      for (final attack in p.omnislashAttacks) {
        SkillArtworkTint.begin(
          canvas,
          p.artworkTint(PowerUpKind.busterSword, ball: attack.owner),
        );
        try {
          final visualRadius =
              r * p.visualSkill(PowerUpKind.busterSword).effectDisplayScale;
          for (var i = 0; i < attack.hitsShown; i++) {
            final angle = i * math.pi / 4 + attack.age * 0.035;
            final direction = Offset.fromDirection(angle);
            canvas.drawLine(
              attack.target.position - direction * visualRadius * 1.6,
              attack.target.position + direction * visualRadius * 1.6,
              Paint()
                ..strokeWidth = math.max(2, visualRadius * 0.16)
                ..color =
                    (i.isEven
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFFFFD54F))
                        .withValues(alpha: 0.86),
            );
          }
        } finally {
          SkillArtworkTint.end(canvas);
        }
      }
    }

    for (final flash in p.sniperFlashes) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.sniperRifle, ball: flash.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.sniperRifle).effectDisplayScale;
        final fade = (1 - flash.age / 24).clamp(0.0, 1.0);
        final from = flash.owner.position;
        final to = flash.target.position;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeWidth = math.max(4, visualRadius * 0.3)
            ..color = Colors.white.withValues(alpha: fade),
        );
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeWidth = math.max(1.5, visualRadius * 0.1)
            ..color = const Color(0xFFFFD54F).withValues(alpha: fade),
        );
        canvas.drawCircle(
          to,
          visualRadius * (0.55 + flash.age * 0.08),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, visualRadius * 0.16)
            ..color = const Color(0xFFFFD54F).withValues(alpha: fade),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final hazard in p.arenaThemeHazards) {
      paintArenaThemeHazard(canvas, hazard, arenaRadius, r, state.step);
    }

    for (final tendril in p.omegaTendrils) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.omegaTendrils, ball: tendril.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.omegaTendrils).effectDisplayScale;
        final from = tendril.owner.position;
        final to = tendril.target.position;
        final delta = to - from;
        final distance = math.max(1.0, delta.distance);
        final normal = Offset(-delta.dy, delta.dx) / distance;
        final progress = 1 - tendril.stepsLeft / 36.0;
        final reach = Curves.easeOutCubic.transform(
          (progress / 0.55).clamp(0.0, 1.0),
        );
        final end = Offset.lerp(from, to, reach)!;
        final wave = math.sin(state.step * 0.55 + to.dx * 0.02);
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(
            from.dx + delta.dx * 0.3 + normal.dx * visualRadius * 0.8 * wave,
            from.dy + delta.dy * 0.3 + normal.dy * visualRadius * 0.8 * wave,
            from.dx + delta.dx * 0.7 - normal.dx * visualRadius * 0.65 * wave,
            from.dy + delta.dy * 0.7 - normal.dy * visualRadius * 0.65 * wave,
            end.dx,
            end.dy,
          );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(5, visualRadius * 0.42)
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFF5B0714),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, visualRadius * 0.18)
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFF304C),
        );
        final sprite = SpriteRegistry.frame(
          PowerUpSprites.omegaTendrilsAttackId,
        );
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            end,
            visualRadius * (0.75 + 0.25 * math.sin(state.step * 0.4).abs()),
            math.atan2(delta.dy, delta.dx),
            opacity: reach,
            anchor: SpriteRegistry.anchor(PowerUpSprites.omegaTendrilsAttackId),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final fire in p.burningZones) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.molotov, ball: fire.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.molotov).effectDisplayScale;
        final life = 1 - fire.age / PowerUpTuning.molotovBurnSteps;
        final pulse = 0.92 + 0.08 * math.sin(state.step * 0.35);
        canvas.drawCircle(
          fire.position,
          fire.radius,
          Paint()
            ..color = const Color(0xFFFF5A20).withValues(alpha: 0.18 * life),
        );
        canvas.drawCircle(
          fire.position,
          fire.radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2, visualRadius * 0.14)
            ..color = const Color(0xFFFFA126).withValues(alpha: 0.9 * life),
        );
        if (showEffects) {
          const fireSpots = [
            Offset(-0.46, -0.12),
            Offset(0.38, -0.22),
            Offset(-0.12, 0.3),
            Offset(0.5, 0.2),
            Offset(0.06, -0.42),
            Offset(-0.5, 0.34),
            Offset(0.22, 0.48),
          ];
          for (var i = 0; i < fireSpots.length; i++) {
            final flame =
                p.usesEffectSprite(
                  PowerUpKind.molotov,
                  ball: fire.owner,
                  globalSprite: explosionRenderMode == EffectRenderMode.sprite,
                )
                ? SpriteRegistry.frameAt(
                    PowerUpSprites.animId(AnimatedEffect.campfire),
                    state.step,
                    offset: i,
                    stepsPerFrame: _campfireStepsPerFrame,
                  )
                : null;
            final flicker = 0.5 + 0.5 * math.sin(state.step * 0.48 + i * 1.73);
            final base = fire.position + fireSpots[i] * fire.radius;
            if (flame != null) {
              _drawEffect(
                canvas,
                flame,
                base,
                fire.radius * (0.42 + (i % 3) * 0.08 + flicker * 0.1) * pulse,
                0,
                opacity: life,
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.animId(AnimatedEffect.campfire),
                ),
              );
            }
          }
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final wall in p.fireWalls) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.fireWall, ball: wall.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.fireWall).effectDisplayScale;
        final tangent = Offset.fromDirection(wall.angle);
        for (var i = 0; i < 4; i++) {
          final flame =
              p.usesEffectSprite(
                PowerUpKind.fireWall,
                ball: wall.owner,
                globalSprite: explosionRenderMode == EffectRenderMode.sprite,
              )
              ? SpriteRegistry.frameAt(
                  PowerUpSprites.animId(AnimatedEffect.campfire),
                  state.step,
                  offset: i,
                  stepsPerFrame: _campfireStepsPerFrame,
                )
              : null;
          final spot = wall.center + tangent * visualRadius * (i - 1.5) * 1.35;
          if (flame != null) {
            _drawEffect(
              canvas,
              flame,
              spot,
              visualRadius *
                  (1.05 + 0.1 * math.sin(state.step * 0.4 + i).abs()),
              0,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.animId(AnimatedEffect.campfire),
              ),
            );
          } else {
            canvas.drawCircle(
              spot,
              visualRadius * 0.45,
              Paint()..color = const Color(0xFFFF6A22),
            );
          }
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final strike in p.lightningStrikes) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.lightningStrikes, ball: strike.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.lightningStrikes).effectDisplayScale;
        if (strike.flashLeft <= 0) continue;
        final target = strike.target.position;
        if (p.usesEffectSprite(
              PowerUpKind.lightningStrikes,
              ball: strike.owner,
              globalSprite: explosionRenderMode == EffectRenderMode.sprite,
            ) &&
            LightningStrikePainter.paint(
              canvas,
              impact: target,
              size: visualRadius * 5,
              step: 8 - strike.flashLeft,
            )) {
          continue;
        }
        final top = Offset(target.dx, -arenaRadius - visualRadius * 1.5);
        final path = Path()..moveTo(top.dx, top.dy);
        const bends = 7;
        for (var i = 1; i <= bends; i++) {
          final t = i / bends;
          final jitter = i == bends
              ? 0.0
              : math.sin(i * 12.7 + state.step * 1.9) * visualRadius * 0.7;
          path.lineTo(
            top.dx + (target.dx - top.dx) * t + jitter,
            top.dy + (target.dy - top.dy) * t,
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(7, visualRadius * 0.5)
            ..color = const Color(0xFF4BAEFF).withValues(alpha: 0.45),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(2, visualRadius * 0.16)
            ..color = const Color(0xFFFFFFB0),
        );
        canvas.drawCircle(
          target,
          visualRadius * (1.2 + strike.flashLeft * 0.05),
          Paint()..color = const Color(0xFFFFFF8A).withValues(alpha: 0.3),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final quake in p.earthquakes) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.earthquake, ball: quake.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.earthquake).effectDisplayScale;
        if (quake.flashLeft <= 0) continue;
        final progress = 1 - quake.flashLeft / 10.0;
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset.zero,
            arenaRadius * (0.3 + progress * 0.65 - i * 0.08),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(3, visualRadius * 0.16)
              ..color = const Color(
                0xFFFFB23F,
              ).withValues(alpha: 0.65 - i * 0.16),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    for (final attack in p.energyWaveAttacks) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.energyWave, ball: attack.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.energyWave).effectDisplayScale;
        final charge = (attack.age / EnergyWaveAttack.chargeSteps).clamp(
          0.0,
          1.0,
        );
        final pulse = 0.86 + 0.14 * math.sin(state.step * 0.65).abs();
        // Keep the caster's face visible: the energy gathers in front of it,
        // rather than replacing the ball with a glowing circle.
        final beamDirection = attack.age < EnergyWaveAttack.chargeSteps
            ? attack.direction
            : Offset.fromDirection(
                attack.startAngle +
                    EnergyWaveAttack.sweepProgress(
                          attack.age - EnergyWaveAttack.chargeSteps,
                        ) *
                        (attack.endAngle - attack.startAngle),
              );
        final orb =
            attack.owner.position + beamDirection * attack.owner.radius * 1.75;
        canvas.drawCircle(
          orb,
          visualRadius * (0.38 + charge * 0.52) * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              orb,
              visualRadius,
              [
                Colors.white.withValues(alpha: 0.96),
                const Color(0xFF2DE7FF).withValues(alpha: 0.88),
                const Color(0x002468FF),
              ],
              const [0.0, 0.55, 1.0],
            ),
        );
        for (var ring = 0; ring < 3; ring++) {
          canvas.drawCircle(
            orb,
            visualRadius * (0.72 + ring * 0.23 + charge * 0.18),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, visualRadius * 0.1)
              ..color = const Color(
                0xFF8EF5FF,
              ).withValues(alpha: (0.7 - ring * 0.18) * pulse),
          );
        }
        for (final target in attack.targets) {
          canvas.drawCircle(
            target.position,
            target.radius * (1.18 + 0.06 * pulse),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, visualRadius * 0.1)
              ..color = const Color(0xFF48DFFF).withValues(alpha: 0.62),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    for (final wave in p.energyWaves) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.energyWave, ball: wave.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.energyWave).effectDisplayScale;
        final initial = wave.end - wave.start;
        final progress = EnergyWaveAttack.sweepProgress(wave.age);
        final startAngle =
            wave.sweepStartAngle ?? math.atan2(initial.dy, initial.dx);
        final endAngle = wave.sweepEndAngle ?? startAngle;
        final angle = startAngle + progress * (endAngle - startAngle);
        final direction = Offset.fromDirection(angle);
        final start = wave.owner.position + direction * wave.owner.radius;
        final end = start + direction * arenaRadius * 2.4;
        // The translucent fan records the area already swept by the beam.
        canvas.save();
        canvas.clipPath(
          Path()..addOval(
            Rect.fromCircle(center: Offset.zero, radius: arenaRadius),
          ),
        );
        canvas.drawArc(
          Rect.fromCircle(
            center: wave.owner.position,
            radius: arenaRadius * 2.4,
          ),
          startAngle,
          progress * (endAngle - startAngle),
          true,
          Paint()..color = const Color(0xFF32E4FF).withValues(alpha: 0.07),
        );
        final fade = ((wave.durationSteps - wave.age) / 12).clamp(0.0, 1.0);
        final beamWidth =
            visualRadius * (2.1 + 0.3 * math.sin(state.step * 0.7).abs());
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = beamWidth * 1.7
            ..color = const Color(0xFF167DFF).withValues(alpha: fade * 0.35),
        );
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = beamWidth
            ..color = const Color(0xFF32E4FF).withValues(alpha: fade * 0.9),
        );
        canvas.drawLine(
          start,
          end,
          Paint()
            ..strokeCap = StrokeCap.round
            ..strokeWidth = beamWidth * 0.38
            ..color = Colors.white.withValues(alpha: fade),
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            start,
            beamWidth * (0.7 + i * 0.3 + wave.age * 0.025),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, visualRadius * 0.1)
              ..color = const Color(
                0xFFA7F7FF,
              ).withValues(alpha: fade * (0.8 - i * 0.2)),
          );
        }
        canvas.restore();
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    for (final cone in p.flameCones) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.flamethrower, ball: cone.owner),
      );
      try {
        final visualRadius =
            r * p.visualSkill(PowerUpKind.flamethrower).effectDisplayScale;
        final direction = Offset.fromDirection(cone.angle);
        final normal = Offset(-direction.dy, direction.dx);
        for (var i = 0; i < 7; i++) {
          final distance = visualRadius * (1.35 + i * 0.78);
          final spread = i * visualRadius * 0.16;
          final flutter = math.sin(state.step * 0.7 + i * 1.9) * spread;
          final center =
              cone.owner.position + direction * distance + normal * flutter;
          final flame =
              p.usesEffectSprite(
                PowerUpKind.flamethrower,
                ball: cone.owner,
                globalSprite: explosionRenderMode == EffectRenderMode.sprite,
              )
              ? SpriteRegistry.frameAt(
                  PowerUpSprites.animId(AnimatedEffect.flame),
                  state.step,
                  offset: i,
                )
              : null;
          if (flame != null) {
            _drawEffect(
              canvas,
              flame,
              center,
              visualRadius * (0.58 + i * 0.13),
              cone.angle,
              opacity: 0.94 - i * 0.045,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.animId(AnimatedEffect.flame),
              ),
            );
          }
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: cone.owner.position,
            radius: arenaRadius * 0.78,
          ),
          cone.angle - 0.48,
          0.96,
          true,
          Paint()..color = const Color(0xFFFF5A1F).withValues(alpha: 0.08),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final e in p.explosions) {
      SkillArtworkTint.begin(
        canvas,
        e.kind == null
            ? 0xFFFFFFFF
            : p.artworkTint(e.kind!, skillId: e.skillId),
      );
      try {
        final visualRadius =
            e.radius *
            (e.kind == null
                ? 1
                : p
                      .visualSkill(e.kind!, skillId: e.skillId)
                      .effectDisplayScale);
        final t = e.age / PowerUpTuning.explosionShowSteps;
        final fade = (1 - t).clamp(0.0, 1.0);
        if (e.kind == PowerUpKind.rocketLauncher &&
            !p.usesEffectSprite(
              PowerUpKind.rocketLauncher,
              skillId: e.skillId,
              globalSprite: explosionRenderMode == EffectRenderMode.sprite,
            )) {
          _paintRocketExplosion(canvas, e.position, visualRadius, t, fade);
          continue;
        }
        if (e.kind == PowerUpKind.grenade &&
            !p.usesEffectSprite(
              PowerUpKind.grenade,
              skillId: e.skillId,
              globalSprite: explosionRenderMode == EffectRenderMode.sprite,
            )) {
          canvas.drawCircle(
            e.position,
            visualRadius * (0.35 + 0.65 * t),
            Paint()
              ..shader = ui.Gradient.radial(
                e.position,
                visualRadius,
                [
                  const Color(0xFFFFF1A0).withValues(alpha: fade),
                  const Color(0xFFFF6B23).withValues(alpha: fade * 0.65),
                  const Color(0x00FF6B23),
                ],
                const [0.0, 0.55, 1.0],
              ),
          );
        }
        if (showEffects &&
            (e.kind == null
                ? explosionRenderMode == EffectRenderMode.sprite
                : p.usesEffectSprite(
                    e.kind!,
                    skillId: e.skillId,
                    globalSprite:
                        explosionRenderMode == EffectRenderMode.sprite,
                  ))) {
          final sprite = SpriteRegistry.frameAtProgress(
            PowerUpSprites.animId(AnimatedEffect.explosion),
            t,
          );
          if (sprite != null) {
            _drawEffect(
              canvas,
              sprite,
              e.position,
              visualRadius,
              t * 0.2,
              opacity: fade,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.animId(AnimatedEffect.explosion),
              ),
            );
            // The sprite is the whole look: no vector ring over it.
            continue;
          }
        }
        canvas.drawCircle(
          e.position,
          visualRadius * (0.6 + 0.4 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFF7A3D).withValues(alpha: fade),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final flash in p.portalFlashes) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(flash.swap ? PowerUpKind.swapCannon : PowerUpKind.portal),
      );
      try {
        final t = flash.age / PowerUpTuning.explosionShowSteps;
        final fade = (1 - t).clamp(0.0, 1.0);
        final portalPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, r * 0.18)
          ..color = colorOf(PowerUpKind.portal).withValues(alpha: fade);
        for (final spot in [flash.from, flash.to]) {
          if (flash.swap) {
            final burst = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, r * 0.15)
              ..color = const Color(0xFF7DF9FF).withValues(alpha: fade);
            for (var i = 0; i < 5; i++) {
              final angle = i * math.pi * 2 / 5 + state.step * 0.08;
              final direction = Offset.fromDirection(angle);
              canvas.drawLine(
                spot + direction * r * 0.25,
                spot + direction * r * (1.6 + t * 1.4),
                burst
                  ..color =
                      (i.isEven
                              ? const Color(0xFF7DF9FF)
                              : const Color(0xFFFF55DD))
                          .withValues(alpha: fade),
              );
            }
            canvas.drawCircle(
              spot,
              r * (0.45 + t * 1.25),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(3, r * 0.22)
                ..color = Colors.white.withValues(alpha: fade),
            );
          }
          final sprite =
              p.usesEffectSprite(
                flash.swap ? PowerUpKind.swapCannon : PowerUpKind.portal,
                globalSprite: explosionRenderMode == EffectRenderMode.sprite,
              )
              ? SpriteRegistry.frameAt(
                  PowerUpSprites.animId(AnimatedEffect.portal),
                  state.step,
                  stepsPerFrame: _portalStepsPerFrame,
                )
              : null;
          if (sprite != null) {
            _drawEffect(
              canvas,
              sprite,
              spot,
              r * (1.1 + t),
              t,
              opacity: fade,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.animId(AnimatedEffect.portal),
              ),
            );
          }
          canvas.drawOval(
            Rect.fromCenter(
              center: spot,
              width: r * (1.2 + t),
              height: r * (2.2 + t * 0.5),
            ),
            portalPaint,
          );
        }
        canvas.drawLine(
          flash.from,
          flash.to,
          portalPaint..color = portalPaint.color.withValues(alpha: fade * 0.25),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final item in p.field) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(item.kind, skillId: item.skillId),
      );
      try {
        // Subtle pulse: the token breathes about once a second.
        final pulse =
            0.5 +
            0.5 * math.sin((state.step - item.spawnStep) * 2 * math.pi / 60);
        if (item.kind.isTrap) {
          _paintTrap(
            canvas,
            item.kind,
            item.position,
            r *
                (0.96 + 0.08 * pulse) *
                p
                    .visualSkill(item.kind, skillId: item.skillId)
                    .pickupDisplayScale,
            useSprite: p.usesSprite(item.kind, skillId: item.skillId),
          );
        } else {
          _paintToken(
            canvas,
            p.visualSkill(item.kind, skillId: item.skillId).displayKind,
            item.position,
            r *
                (0.90 + 0.20 * pulse) *
                p
                    .visualSkill(item.kind, skillId: item.skillId)
                    .pickupDisplayScale,
            0.35 + 0.65 * pulse,
            ring: p.match.tuning.rarityOf(item.kind)?.color,
            useSprite: p.usesSprite(item.kind, skillId: item.skillId),
            whiteBackground: whitePickupBackgrounds,
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final casing in p.shellCasings) {
      canvas.save();
      canvas.translate(casing.position.dx, casing.position.dy);
      canvas.rotate(casing.angle);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: math.max(2.5, r * 0.2),
          height: math.max(1.5, r * 0.1),
        ),
        const Radius.circular(1),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFFD8A63A));
      canvas.drawLine(
        Offset(body.right - 0.7, body.top),
        Offset(body.right - 0.7, body.bottom),
        Paint()
          ..strokeWidth = 0.8
          ..color = const Color(0xFFFFE09A),
      );
      canvas.restore();
    }

    for (final portal in p.portals) {
      SkillArtworkTint.begin(canvas, p.artworkTint(PowerUpKind.portal));
      try {
        final trapRadius =
            r * p.visualSkill(PowerUpKind.portal).effectDisplayScale;
        final pulse =
            0.5 +
            0.5 * math.sin((state.step - portal.spawnStep) * 2 * math.pi / 60);
        final anchor = portal.position.distance == 0
            ? portal.position
            : portal.position / portal.position.distance * arenaRadius;
        canvas.save();
        canvas.translate(anchor.dx, anchor.dy);
        canvas.rotate(portalRotationFor(portal.position));
        final sprite =
            p.usesEffectSprite(
              PowerUpKind.portal,
              globalSprite: explosionRenderMode == EffectRenderMode.sprite,
            )
            ? SpriteRegistry.frameAt(
                PowerUpSprites.animId(AnimatedEffect.portal),
                state.step,
                stepsPerFrame: _portalStepsPerFrame,
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            Offset.zero,
            trapRadius * (1.42 + pulse * 0.08),
            0,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.animId(AnimatedEffect.portal),
            ),
          );
        } else {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: trapRadius * (1.25 + pulse * 0.08),
              height: trapRadius * (2.5 + pulse * 0.12),
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, trapRadius * 0.13)
              ..color = colorOf(PowerUpKind.portal),
          );
        }
        canvas.restore();
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final wall in p.spikeWalls) {
      SkillArtworkTint.begin(canvas, p.artworkTint(PowerUpKind.spikeWall));
      try {
        final trapRadius =
            r * p.visualSkill(PowerUpKind.spikeWall).effectDisplayScale;
        final spacing = trapRadius * 0.96;
        for (final rawBase in wall.spikePositions(spacing)) {
          // Old/replayed walls may have been spawned slightly farther inward.
          // Project every visual base to the rim so the wooden rail touches it.
          final base = rawBase.distance == 0
              ? rawBase
              : rawBase /
                    rawBase.distance *
                    spikeBaseRadius(arenaRadius, trapRadius);
          final angle = math.atan2(base.dy, base.dx);
          final radial = Offset(math.cos(angle), math.sin(angle));
          final tangent = Offset(-radial.dy, radial.dx);
          _paintBoundarySpike(canvas, base, radial, tangent, trapRadius);
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final goo in p.stickyGoo) {
      SkillArtworkTint.begin(canvas, p.artworkTint(PowerUpKind.stickyGoo));
      try {
        final trapRadius =
            r * p.visualSkill(PowerUpKind.stickyGoo).effectDisplayScale;
        final pulse =
            0.9 + 0.08 * math.sin((state.step - goo.spawnStep) * 0.12);
        _paintCurvedGooStrip(canvas, goo, arenaRadius, trapRadius, pulse);
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    for (final swamp in p.poisonSwamps) {
      SkillArtworkTint.begin(canvas, p.artworkTint(PowerUpKind.poisonSwamp));
      try {
        final trapRadius =
            r * p.visualSkill(PowerUpKind.poisonSwamp).effectDisplayScale;
        final pulse =
            0.92 + 0.06 * math.sin((state.step - swamp.spawnStep) * 0.1);
        _paintCurvedGooStrip(
          canvas,
          StickyGoo(position: swamp.position, spawnStep: swamp.spawnStep),
          arenaRadius,
          trapRadius,
          pulse,
          tint: const Color(0xFF669B22),
        );
        for (var i = 0; i < 5; i++) {
          final angle =
              math.atan2(swamp.position.dy, swamp.position.dx) +
              (i - 2) * trapRadius * 0.82 / arenaRadius;
          final spot = Offset.fromDirection(
            angle,
            arenaRadius - trapRadius * 0.7,
          );
          canvas.drawCircle(
            spot +
                Offset(0, math.sin(state.step * 0.12 + i) * trapRadius * 0.12),
            trapRadius * (0.08 + (i % 2) * 0.04),
            Paint()..color = const Color(0xFFCAFF54).withValues(alpha: 0.8),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final bomb in p.mines) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(bomb.kind, ball: bomb.owner),
      );
      try {
        final trapRadius = r * p.visualSkill(bomb.kind).effectDisplayScale;
        // Armed traps sit directly on the arena instead of looking like pickup
        // balls. The short owner-colored footing preserves ownership feedback.
        final blink = ((state.step - bomb.armedStep) ~/ 15).isEven;
        _paintTrap(
          canvas,
          bomb.kind,
          bomb.position,
          trapRadius,
          useSprite: p.usesSprite(bomb.kind),
        );
        canvas.drawLine(
          bomb.position + Offset(-trapRadius * 0.65, trapRadius * 0.78),
          bomb.position + Offset(trapRadius * 0.65, trapRadius * 0.78),
          Paint()
            ..strokeWidth = math.max(2, trapRadius * 0.14)
            ..strokeCap = StrokeCap.round
            ..color = bomb.owner.config.primaryColor.withValues(
              alpha: bomb.kind == PowerUpKind.phaseMine ? 0.35 : 0.9,
            ),
        );
        canvas.drawCircle(
          bomb.position + Offset(trapRadius * 0.62, -trapRadius * 0.62),
          math.max(2.5, trapRadius * 0.18),
          Paint()
            ..color = blink ? const Color(0xFFFF3B30) : const Color(0xFF5A1A16),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final ball in state.balls) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(ball.held ?? PowerUpKind.pistol, ball: ball),
      );
      try {
        final target = ball.aimTarget;
        if (ball.isEliminated || target == null || ball.aimLeft <= 0) continue;
        canvas.drawLine(
          ball.position,
          target.position,
          Paint()
            ..strokeWidth = 1
            ..color = colorOf(
              ball.held ?? PowerUpKind.pistol,
            ).withValues(alpha: 0.45),
        );
        if (ball.equippedWeapons.contains(PowerUpKind.energyWave)) {
          final toTarget = target.position - ball.position;
          if (toTarget.distance > 0) {
            final charge =
                1 - ball.aimLeft / math.max(1, PowerUpTuning.aimSteps);
            final orb =
                ball.position +
                toTarget / toTarget.distance * ball.radius * 1.3;
            canvas.drawCircle(
              orb,
              r * (0.35 + charge * 0.75),
              Paint()
                ..shader = ui.Gradient.radial(
                  orb,
                  r * 1.2,
                  [
                    Colors.white,
                    const Color(0xFF27E5FF),
                    const Color(0x00216CFF),
                  ],
                  const [0.0, 0.55, 1.0],
                ),
            );
          }
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    if (p.projectiles.isNotEmpty) {
      // Vector fallback keeps each projectile's configured dimensions.
      final len = math.max(6.0, r * 0.6);
      for (final shot in p.projectiles) {
        SkillArtworkTint.begin(
          canvas,
          p.artworkTint(shot.kind, projectile: shot),
        );
        try {
          final shotRadius = r * shot.renderScale;
          if (shot.kind == PowerUpKind.hook) {
            // The hook flying out on its chain.
            _paintChain(canvas, shot.owner.position, shot.position);
            final sprite =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? SpriteRegistry.frame(
                    PowerUpSprites.projectileId(ProjectileSprite.harpoon),
                  )
                : null;
            final angle = math.atan2(shot.velocity.dy, shot.velocity.dx);
            if (sprite == null) {
              drawGlyph(
                canvas,
                PowerUpKind.hook,
                shot.position,
                shotRadius * 0.6,
              );
            } else {
              _drawSprite(
                canvas,
                sprite,
                shot.position,
                shotRadius * 0.9,
                angle,
                flip: shot.velocity.dx < 0,
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.projectileId(ProjectileSprite.harpoon),
                ),
              );
            }
            continue;
          }
          if (shot.landAt != null) {
            // A thrown explosive in flight: its own icon, tumbling.
            final sprite =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? PowerUpSprites.of(shot.kind)
                : null;
            if (sprite == null) {
              drawGlyph(canvas, shot.kind, shot.position, shotRadius * 0.5);
            } else {
              _drawSprite(
                canvas,
                sprite,
                shot.position,
                shotRadius * 0.6,
                state.step * 0.3,
                anchor: SpriteRegistry.anchor(PowerUpSprites.iconId(shot.kind)),
              );
            }
            continue;
          }
          if (shot.kind == PowerUpKind.freeze) {
            final sprite =
                p.usesEffectSprite(
                  shot.kind,
                  projectile: shot,
                  globalSprite: freezeRenderMode == EffectRenderMode.sprite,
                )
                ? SpriteRegistry.frame(
                    PowerUpSprites.effectId(EffectSprite.iceWave),
                  )
                : null;
            if (sprite == null) {
              _paintIceWave(canvas, shot, shotRadius);
            } else {
              _drawEffect(
                canvas,
                sprite,
                shot.position,
                shotRadius * 1.45,
                math.atan2(shot.velocity.dy, shot.velocity.dx),
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.effectId(EffectSprite.iceWave),
                ),
              );
            }
            continue;
          }
          if (shot.kind == PowerUpKind.bow) {
            _paintArrow(
              canvas,
              shot,
              shotRadius,
              useSprite:
                  projectileRenderMode == EffectRenderMode.sprite &&
                  p.usesSprite(shot.kind, projectile: shot),
            );
            continue;
          }
          final speed = shot.velocity.distance;
          if (speed == 0) continue;
          final dir = shot.velocity / speed;
          if (shot.kind == PowerUpKind.rocketLauncher) {
            final missile =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? SpriteRegistry.frame(PowerUpSprites.rocketMissileId)
                : null;
            if (missile != null) {
              final thrust = 0.88 + 0.12 * math.sin(state.step * 0.7).abs();
              _drawSprite(
                canvas,
                missile,
                shot.position - dir * shotRadius * 0.45,
                shotRadius * 1.05 * thrust,
                math.atan2(dir.dy, dir.dx),
                anchor: SpriteRegistry.anchor(PowerUpSprites.rocketMissileId),
              );
            } else {
              drawGlyph(canvas, shot.kind, shot.position, shotRadius * 0.6);
            }
            continue;
          }
          if (shot.kind == PowerUpKind.boomerang) {
            final sprite =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? SpriteRegistry.frame(PowerUpSprites.boomerangProjectileId)
                : null;
            if (sprite != null) {
              _drawSprite(
                canvas,
                sprite,
                shot.position,
                shotRadius * 1.6,
                state.step * shot.spinDegreesPerSecond * math.pi / 10800,
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.boomerangProjectileId,
                ),
              );
            } else {
              drawGlyph(canvas, shot.kind, shot.position, shotRadius * 0.65);
            }
            continue;
          }
          if (shot.kind == PowerUpKind.waterGun) {
            final wave = math.sin(state.step * 0.8) * shotRadius * 0.14;
            final normal = Offset(-dir.dy, dir.dx);
            final tail = shot.position - dir * shotRadius * 2.2;
            final path = Path()
              ..moveTo(tail.dx, tail.dy)
              ..quadraticBezierTo(
                (tail.dx + shot.position.dx) / 2 + normal.dx * wave,
                (tail.dy + shot.position.dy) / 2 + normal.dy * wave,
                shot.position.dx,
                shot.position.dy,
              );
            canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeCap = StrokeCap.round
                ..strokeWidth = math.max(3, shotRadius * 0.34)
                ..color = const Color(0xFF48CFFF),
            );
            canvas.drawCircle(
              shot.position,
              shotRadius * 0.26,
              Paint()..color = const Color(0xFFC9F7FF),
            );
            continue;
          }
          if (shot.kind == PowerUpKind.swapCannon) {
            final angle = math.atan2(dir.dy, dir.dx);
            final normal = Offset(-dir.dy, dir.dx);
            for (var i = 4; i >= 1; i--) {
              final center =
                  shot.position - dir * shotRadius * i.toDouble() * 0.48;
              canvas.drawOval(
                Rect.fromCenter(
                  center:
                      center +
                      normal *
                          math.sin(state.step * 0.5 + i) *
                          shotRadius *
                          0.15,
                  width: shotRadius * (0.35 + i * 0.08),
                  height: shotRadius * (0.9 + i * 0.12),
                ),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = math.max(1.5, shotRadius * 0.09)
                  ..color =
                      (i.isEven
                              ? const Color(0xFF7DF9FF)
                              : const Color(0xFFFF55DD))
                          .withValues(alpha: 0.18 + (4 - i) * 0.13),
              );
            }
            final sprite =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? SpriteRegistry.frame(
                    PowerUpSprites.projectileId(ProjectileSprite.swapCannon),
                  )
                : null;
            if (sprite != null) {
              _drawSprite(
                canvas,
                sprite,
                shot.position,
                shotRadius * 0.72,
                angle,
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.projectileId(ProjectileSprite.swapCannon),
                ),
              );
            } else {
              canvas.drawCircle(
                shot.position,
                shotRadius * 0.28,
                Paint()..color = Colors.white,
              );
            }
            continue;
          }
          if (shot.kind == PowerUpKind.threadHarpoon) {
            final sprite =
                projectileRenderMode == EffectRenderMode.sprite &&
                    p.usesSprite(shot.kind, projectile: shot)
                ? SpriteRegistry.frame(
                    PowerUpSprites.projectileId(ProjectileSprite.harpoon),
                  )
                : null;
            if (sprite == null) {
              drawGlyph(canvas, shot.kind, shot.position, shotRadius * 0.6);
            } else {
              _drawSprite(
                canvas,
                sprite,
                shot.position,
                shotRadius * 0.9,
                math.atan2(dir.dy, dir.dx),
                flip: dir.dx < 0,
                anchor: SpriteRegistry.anchor(
                  PowerUpSprites.projectileId(ProjectileSprite.harpoon),
                ),
              );
            }
            continue;
          }
          final projectileKind = _projectileSpriteFor(shot.kind);
          final projectile =
              projectileKind == null ||
                  projectileRenderMode != EffectRenderMode.sprite ||
                  !p.usesSprite(shot.kind, projectile: shot)
              ? null
              : SpriteRegistry.frame(
                  PowerUpSprites.projectileId(projectileKind),
                );
          if (projectile != null) {
            _drawSprite(
              canvas,
              projectile,
              shot.position,
              shotRadius *
                  (shot.kind == PowerUpKind.ricochetDisc ? 0.75 : 0.62),
              math.atan2(dir.dy, dir.dx) +
                  state.step * shot.spinDegreesPerSecond * math.pi / 10800,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.projectileId(projectileKind!),
              ),
            );
            continue;
          }
          final length = len * shot.renderScale;
          final front = shot.position;
          final mid = front - dir * (length * 0.45);
          final back = front - dir * length;
          final tail = front - dir * (length * 3.5);
          canvas.drawLine(tail, back, _trailPaint..strokeWidth = length * 0.35);
          canvas.drawLine(back, mid, _casingPaint..strokeWidth = length * 0.5);
          canvas.drawLine(mid, front, _tipPaint..strokeWidth = length * 0.5);
        } finally {
          SkillArtworkTint.end(canvas);
        }
      }
    }

    // Hooked balls on their chain, being reeled in.
    for (final h in p.pulls) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.hook, ball: h.owner),
      );
      try {
        _paintChain(canvas, h.owner.position, h.target.position);
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }

    for (final m in p.slashMarks) {
      SkillArtworkTint.begin(canvas, p.artworkTint(m.kind, skillId: m.skillId));
      try {
        // Two quick strokes across the cut, fading out.
        final fade = (1 - m.age / PowerUpTuning.slashShowSteps).clamp(0.0, 1.0);
        final sprite =
            p.usesEffectSprite(
              m.kind,
              skillId: m.skillId,
              globalSprite: explosionRenderMode == EffectRenderMode.sprite,
            )
            ? SpriteRegistry.frameAtProgress(
                PowerUpSprites.animId(AnimatedEffect.slash),
                m.age / PowerUpTuning.slashShowSteps,
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            m.position,
            r * 1.8,
            m.angle,
            opacity: fade,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.animId(AnimatedEffect.slash),
            ),
          );
          continue;
        }
        final along = Offset(math.cos(m.angle), math.sin(m.angle)) * (r * 1.6);
        final across = Offset(-along.dy, along.dx) * 0.18;
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: fade);
        for (final shift in [-1.0, 1.0]) {
          final o = m.position + across * shift;
          canvas.drawLine(o - along, o + along, paint);
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
  }

  /// Tornadoes that have reached a victim are centered over that ball and are
  /// painted after contestants, so the funnel visibly surrounds the victim.
  static Offset tornadoVisualCenter(SimulationBall target) => target.position;

  static void paintTornadoOverlays(
    Canvas canvas,
    SimulationState state, {
    bool globalEffectSprite = true,
  }) {
    final p = state.powerUps;
    if (p == null) return;
    for (final tornado in p.tornadoes) {
      SkillArtworkTint.begin(
        canvas,
        p.artworkTint(PowerUpKind.tornado, ball: tornado.owner),
      );
      try {
        final target = tornado.target;
        if (target.isEliminated) continue;
        if (tornado.isAiming) {
          final owner = tornado.owner;
          final scale = p.handEffectScale(PowerUpKind.tornado);
          final wind = Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = math.max(2, owner.radius * 0.1)
            ..color = p
                .handEffectColor(PowerUpKind.tornado)
                .withValues(alpha: 0.85);
          for (final side in const [-1.0, 1.0]) {
            final hand = owner.position + Offset(side * owner.radius * 0.82, 0);
            for (var ring = 0; ring < 3; ring++) {
              final phase = (state.step * 0.18 + ring * 0.7) % 2;
              canvas.drawArc(
                Rect.fromCircle(
                  center: hand,
                  radius: owner.radius * (0.2 + phase * 0.16) * scale,
                ),
                -math.pi * 0.8,
                math.pi * 1.6,
                false,
                wind,
              );
            }
          }
          continue;
        }
        final center = tornadoVisualCenter(target);
        final half =
            target.radius *
            1.65 *
            p.visualSkill(PowerUpKind.tornado).effectDisplayScale;
        final frame =
            p.usesEffectSprite(
              PowerUpKind.tornado,
              ball: tornado.owner,
              globalSprite: globalEffectSprite,
            )
            ? SpriteRegistry.frameAt(
                PowerUpSprites.animId(AnimatedEffect.tornado),
                state.step,
              )
            : null;
        if (frame != null) {
          _drawEffect(
            canvas,
            frame,
            center,
            half,
            0,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.animId(AnimatedEffect.tornado),
            ),
          );
        } else {
          for (var i = 0; i < 3; i++) {
            canvas.drawOval(
              Rect.fromCenter(
                center: center + Offset(0, (i - 1) * target.radius * 0.38),
                width: target.radius * (2.8 - i * 0.5),
                height: target.radius * 0.5,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = math.max(2, target.radius * 0.12)
                ..color = const Color(0xFFD8F8FF).withValues(alpha: 0.8),
            );
          }
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
  }

  static void paintArenaThemeHazard(
    Canvas canvas,
    ArenaThemeHazard hazard,
    double arenaRadius,
    double itemRadius,
    int step,
  ) {
    final radius = arenaRadius * 0.18;
    final pulse = 0.92 + math.sin((step - hazard.spawnStep) * 0.12) * 0.08;
    switch (hazard.kind) {
      case ArenaThemeHazardKind.gravityWell:
        for (var i = 3; i >= 1; i--) {
          canvas.drawCircle(
            hazard.position,
            radius * pulse * i / 3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(2, itemRadius * 0.12)
              ..color = Color.lerp(
                const Color(0xFF00E5FF),
                const Color(0xFFB620E0),
                i / 3,
              )!.withValues(alpha: 0.75),
          );
        }
        canvas.drawCircle(
          hazard.position,
          radius * 0.28,
          Paint()..color = const Color(0xFF02030A),
        );
      case ArenaThemeHazardKind.quicksand:
        canvas.drawOval(
          Rect.fromCenter(
            center: hazard.position,
            width: radius * 2.2 * pulse,
            height: radius * 1.55 * pulse,
          ),
          Paint()..color = const Color(0xFF7A4828).withValues(alpha: 0.78),
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: hazard.position,
              width: radius * (1.7 - i * 0.42),
              height: radius * (1.05 - i * 0.22),
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFF0C276).withValues(alpha: 0.7),
          );
        }
      case ArenaThemeHazardKind.vineSnare:
        final vine = Paint()
          ..color = const Color(0xFF9CCC65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(3, itemRadius * 0.18)
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5 + step * 0.01;
          final end =
              hazard.position + Offset.fromDirection(angle, radius * pulse);
          canvas.drawArc(
            Rect.fromPoints(
              hazard.position - const Offset(18, 18),
              end + const Offset(18, 18),
            ),
            angle,
            math.pi * 0.8,
            false,
            vine,
          );
        }
      case ArenaThemeHazardKind.laserGate:
        final direction = Offset(
          math.cos(hazard.angle),
          math.sin(hazard.angle),
        );
        final from = direction * -arenaRadius;
        final to = direction * arenaRadius;
        final flicker = 0.55 + 0.45 * math.sin(step * 0.32).abs();
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = const Color(
              0xFFFF2BD6,
            ).withValues(alpha: 0.18 + flicker * 0.2)
            ..strokeWidth = itemRadius * (0.7 + flicker * 0.35),
        );
        canvas.drawLine(
          from,
          to,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFFFFF),
              const Color(0xFF00E5FF),
              flicker,
            )!
            ..strokeWidth = math.max(2, itemRadius * (0.1 + flicker * 0.08)),
        );
        for (final emitter in [from, to]) {
          canvas.drawCircle(
            emitter,
            itemRadius * 0.72,
            Paint()..color = const Color(0xFF02030A),
          );
          canvas.drawCircle(
            emitter,
            itemRadius * (0.38 + flicker * 0.08),
            Paint()..color = const Color(0xFFFF2BD6).withValues(alpha: 0.9),
          );
        }
    }
  }

  static void _paintRocketExplosion(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
    double fade,
  ) {
    final eased = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final blastRadius = radius * (0.18 + eased * 0.82);
    final rayPaint = Paint()
      ..color = const Color(0xFFFFB000).withValues(alpha: fade * 0.9)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(2, radius * 0.055 * fade);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6 + progress * 0.28;
      final inner = center + Offset.fromDirection(angle, blastRadius * 0.38);
      final outer =
          center +
          Offset.fromDirection(
            angle,
            blastRadius * (0.78 + (i.isEven ? 0.18 : 0)),
          );
      canvas.drawLine(inner, outer, rayPaint);
    }
    canvas.drawCircle(
      center,
      blastRadius * 0.72,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          blastRadius * 0.72,
          [
            Colors.white.withValues(alpha: fade),
            const Color(0xFFFFD43B).withValues(alpha: fade * 0.95),
            const Color(0xFFFF4B22).withValues(alpha: fade * 0.72),
            const Color(0x00251512),
          ],
          const [0, 0.22, 0.62, 1],
        ),
    );
    canvas.drawCircle(
      center,
      blastRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, radius * 0.035)
        ..color = Colors.white.withValues(alpha: fade * 0.8),
    );
  }

  static void _paintCurvedGooStrip(
    Canvas canvas,
    StickyGoo goo,
    double arenaRadius,
    double r,
    double pulse, {
    Color? tint,
  }) {
    final sprite = SpriteRegistry.frame(PowerUpSprites.stickyGooRimId);
    if (sprite == null || goo.position.distance == 0) return;
    const slices = 56;
    final centerAngle = math.atan2(goo.position.dy, goo.position.dx);
    final arcWidth = r * 5.15 * pulse;
    final sweep = arcWidth / arenaRadius;
    final sourceWidth = sprite.width / slices;
    final destinationWidth = arcWidth / slices + 1.4;
    final destinationHeight = r * 1.55;
    for (var i = 0; i < slices; i++) {
      final u = (i + 0.5) / slices;
      final angle = centerAngle - sweep / 2 + sweep * u;
      final anchor = Offset.fromDirection(angle, arenaRadius);
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      // Local x follows the tangent; local y points inward into the arena.
      canvas.rotate(angle + math.pi / 2);
      canvas.drawImageRect(
        sprite,
        Rect.fromLTWH(
          i * sourceWidth,
          0,
          sourceWidth,
          sprite.height.toDouble(),
        ),
        Rect.fromLTWH(
          -destinationWidth * 0.55,
          0,
          destinationWidth * 1.1,
          destinationHeight,
        ),
        Paint()
          ..filterQuality = FilterQuality.none
          ..colorFilter = tint == null
              ? null
              : ColorFilter.mode(tint, BlendMode.modulate),
      );
      canvas.restore();
    }
  }

  static void _paintBoundarySpike(
    Canvas canvas,
    Offset base,
    Offset radial,
    Offset tangent,
    double radius,
  ) {
    final left = base - tangent * radius * 0.46 + radial * radius * 0.4;
    final right = base + tangent * radius * 0.46 + radial * radius * 0.4;
    final tip = base - radial * radius * 0.95;
    final spike = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(
      spike,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, radius * 0.2)
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF271D28),
    );
    canvas.drawPath(spike, Paint()..color = const Color(0xFFB8BDC8));
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          (base - tangent * radius * 0.14 - radial * radius * 0.05).dx,
          (base - tangent * radius * 0.14 - radial * radius * 0.05).dy,
        )
        ..lineTo(
          (left + radial * radius * 0.05).dx,
          (left + radial * radius * 0.05).dy,
        )
        ..close(),
      Paint()..color = const Color(0xFFF0F4FF),
    );
    canvas.drawLine(
      left,
      right,
      Paint()
        ..strokeWidth = math.max(2, radius * 0.16)
        ..strokeCap = StrokeCap.square
        ..color = const Color(0xFF6D3F2D),
    );
  }

  /// The triangle base is drawn another 0.4 spike radii outward, placing its
  /// rail exactly on the arena circumference.
  static double spikeBaseRadius(double arenaRadius, double spikeRadius) =>
      arenaRadius - spikeRadius * 0.4;

  /// Rotation for a vertically-authored portal oval so its long axis follows
  /// the tangent of the circular arena edge at [position].
  static double portalRotationFor(Offset position) =>
      position.distance == 0 ? 0 : math.atan2(position.dy, position.dx);

  static final Paint _trailPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..color = const Color(0x33FFF3C4);
  static final Paint _casingPaint = Paint()
    ..strokeCap = StrokeCap.butt
    ..color = const Color(0xFFF2C14E);
  static final Paint _tipPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFE08A4F);

  static final Paint _iceArc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static void _paintArrow(
    Canvas canvas,
    Projectile shot,
    double r, {
    bool useSprite = true,
  }) {
    final speed = shot.velocity.distance;
    if (speed == 0) return;
    final direction = shot.velocity / speed;
    final sprite = useSprite
        ? SpriteRegistry.frame(
            PowerUpSprites.projectileId(ProjectileSprite.bow),
          )
        : null;
    if (sprite != null) {
      _drawSprite(
        canvas,
        sprite,
        shot.position - direction * r * 0.45,
        r * 0.85,
        math.atan2(direction.dy, direction.dx),
        anchor: SpriteRegistry.anchor(
          PowerUpSprites.projectileId(ProjectileSprite.bow),
        ),
      );
      return;
    }
    final side = Offset(-direction.dy, direction.dx);
    final tip = shot.position;
    final tail = tip - direction * (r * 1.8);
    final paint = Paint()
      ..strokeWidth = math.max(1.5, r * 0.12)
      ..strokeCap = StrokeCap.round
      ..color = colorOf(PowerUpKind.bow);
    canvas.drawLine(tail, tip, paint);
    canvas.drawLine(tip, tip - direction * r * 0.48 + side * r * 0.3, paint);
    canvas.drawLine(tip, tip - direction * r * 0.48 - side * r * 0.3, paint);
    final feather = Paint()
      ..strokeWidth = math.max(1.2, r * 0.1)
      ..color = const Color(0xFFF2C94C);
    canvas.drawLine(
      tail,
      tail + direction * r * 0.42 + side * r * 0.28,
      feather,
    );
    canvas.drawLine(
      tail,
      tail + direction * r * 0.42 - side * r * 0.28,
      feather,
    );
  }

  static ProjectileSprite? _projectileSpriteFor(PowerUpKind kind) =>
      switch (kind) {
        PowerUpKind.pistol => ProjectileSprite.pistol,
        PowerUpKind.shotgun => ProjectileSprite.shotgun,
        PowerUpKind.gatling => ProjectileSprite.gatling,
        PowerUpKind.prismLaser => ProjectileSprite.prismLaser,
        PowerUpKind.swapCannon => ProjectileSprite.swapCannon,
        PowerUpKind.threadHarpoon => ProjectileSprite.harpoon,
        PowerUpKind.ricochetDisc => ProjectileSprite.ricochetDisc,
        _ => null,
      };

  /// A freeze shot as an icy blast: pale arcs facing forward, widening the farther the shot has flown,
  /// a white core and a few frost sparkles behind it.
  static void _paintIceWave(Canvas canvas, Projectile shot, double r) {
    final speed = shot.velocity.distance;
    if (speed == 0) return;
    final angle = math.atan2(shot.velocity.dy, shot.velocity.dx);
    final dir = shot.velocity / speed;
    // Grows from a ball's edge outward as it travels.
    final travelled = (shot.position - shot.owner.position).distance;
    final grow = (travelled / (r * 8)).clamp(0.0, 1.0);
    // Draw this effect directly so adjacent atlas cells cannot bleed into it.
    // A soft frosty glow around the blast (a gradient, no blur).
    final glowR = r * (1.2 + 1.2 * grow);
    canvas.drawCircle(
      shot.position - dir * (r * 0.4),
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(shot.position - dir * (r * 0.4), glowR, [
          const Color(0x667FDBFF),
          const Color(0x007FDBFF),
        ]),
    );
    for (var i = 0; i < 3; i++) {
      final back = shot.position - dir * (i * r * 0.55);
      final radius = r * (0.9 + 1.3 * grow) * (1 - i * 0.18);
      _iceArc
        ..strokeWidth = math.max(1.5, r * (0.32 - i * 0.08))
        ..color = Color.lerp(
          const Color(0xFFE8FBFF),
          const Color(0xFF7FDBFF),
          i / 2,
        )!.withValues(alpha: 0.95 - i * 0.28);
      canvas.drawArc(
        Rect.fromCircle(center: back - dir * radius, radius: radius),
        angle - 0.75,
        1.5,
        false,
        _iceArc,
      );
    }
    canvas.drawCircle(
      shot.position,
      math.max(2.0, r * 0.22),
      Paint()..color = const Color(0xFFF4FDFF),
    );
    final side = Offset(-dir.dy, dir.dx);
    final sparkles = Float32List(8);
    for (var i = 0; i < 4; i++) {
      final o =
          shot.position -
          dir * (r * (0.9 + i * 0.5)) +
          side * (r * 0.5 * math.sin(travelled * 0.05 + i * 2.1));
      sparkles
        ..[i * 2] = o.dx
        ..[i * 2 + 1] = o.dy;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      sparkles,
      Paint()
        ..strokeWidth = math.max(1.5, r * 0.14)
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCBFEFFF),
    );
  }

  static final Paint _chainPaint = Paint()
    ..strokeWidth = 2.5
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFB0B4BC);

  /// A chain from [from] to [to]: short dashes, one batched call.
  static void _paintChain(Canvas canvas, Offset from, Offset to) {
    final d = to - from;
    final length = d.distance;
    if (length < 1) return;
    final unit = d / length;
    const link = 7.0;
    final count = (length / link).floor();
    final points = Float32List(count * 4);
    var n = 0;
    for (var i = 0; i < count; i++) {
      final a = from + unit * (i * link);
      final b = from + unit * (i * link + link * 0.6);
      points
        ..[n++] = a.dx
        ..[n++] = a.dy
        ..[n++] = b.dx
        ..[n++] = b.dy;
    }
    canvas.drawRawPoints(ui.PointMode.lines, points, _chainPaint);
  }

  /// A power-up token drawn like a small ball: a white ball with a ring in the power-up's color ([ring]
  /// instead if given, e.g. an armed mine's owner) at [ringAlpha], a soft glow, and the icon inside.
  static void _paintToken(
    Canvas canvas,
    PowerUpKind kind,
    Offset c,
    double r,
    double ringAlpha, {
    Color? ring,
    bool useSprite = true,
    bool whiteBackground = true,
  }) {
    final color = ring ?? colorOf(kind);
    canvas.drawCircle(
      c,
      r * 1.5,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 1.5,
          [
            color.withValues(alpha: 0.35 * ringAlpha),
            color.withValues(alpha: 0),
          ],
          [0.6, 1],
        ),
    );
    if (whiteBackground) {
      canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF4F4F2));
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.14)
        ..color = Color.lerp(
          const Color(0xFFF4F4F2),
          color,
          0.4 + 0.6 * ringAlpha,
        )!,
    );
    final sprite = useSprite ? PowerUpSprites.of(kind) : null;
    if (sprite == null) {
      drawGlyph(canvas, kind, c, r * 0.62);
    } else {
      _drawSprite(
        canvas,
        sprite,
        c,
        r * 0.68,
        0,
        anchor: SpriteRegistry.anchor(PowerUpSprites.iconId(kind)),
      );
    }
  }

  /// Arena traps are fixtures, not collectible balls: draw only their sprite
  /// (or vector glyph while sprites load), with no white orb, ring, or glow.
  static void _paintTrap(
    Canvas canvas,
    PowerUpKind kind,
    Offset center,
    double radius, {
    bool useSprite = true,
  }) {
    final sprite = useSprite ? PowerUpSprites.of(kind) : null;
    if (sprite == null) {
      drawGlyph(canvas, kind, center, radius * 0.9);
    } else {
      _drawSprite(
        canvas,
        sprite,
        center,
        radius * 0.95,
        0,
        anchor: SpriteRegistry.anchor(PowerUpSprites.iconId(kind)),
      );
    }
  }

  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;

  /// Draws [image] with its sprite [anchor] (`SpriteRegistry.anchor(id)` of the sprite it came from) at
  /// [c], [half] in half-size. The icon is first turned so its own direction
  /// [iconAngle] lies along +x, then mirrored top-to-bottom if [flip] (so a gun pointing left isn't upside
  /// down), then turned to [rotation].
  static void _drawSprite(
    Canvas canvas,
    ui.Image image,
    Offset c,
    double half,
    double rotation, {
    required Offset anchor,
    double iconAngle = 0,
    bool flip = false,
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (flip) canvas.scale(1, -1);
    if (iconAngle != 0) canvas.rotate(-iconAngle);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      SpriteRegistry.placeRect(Offset.zero, 2 * half, 2 * half, anchor),
      opacity >= 1
          ? _spritePaint
          : (Paint()
              ..filterQuality = FilterQuality.none
              ..colorFilter = ColorFilter.mode(
                Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
                BlendMode.modulate,
              )),
    );
    canvas.restore();
  }

  /// Draws [image] [half] in half-size with its sprite [anchor]
  /// (`SpriteRegistry.anchor(id)` of the sprite it came from) at [center],
  /// turned by [rotation] around it.
  static void _drawEffect(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double half,
    double rotation, {
    required Offset anchor,
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      SpriteRegistry.placeRect(Offset.zero, half * 2, half * 2, anchor),
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
          BlendMode.modulate,
        ),
    );
    canvas.restore();
  }

  /// The direction, in radians, each weapon icon points in as drawn in its SVG (guns: the muzzle; knife:
  /// the tip). Weapons are turned from it to point where they are used.
  static const Map<PowerUpKind, double> _iconAngle = {
    PowerUpKind.knife: -math.pi / 4,
    PowerUpKind.sword: -math.pi / 4,
    // Hook and harpoon artwork have opposite handle orientations.
    PowerUpKind.hook: 3 * math.pi / 4,
    PowerUpKind.threadHarpoon: -math.pi / 4,
  };

  /// The direction in which [ball]'s held item is drawn. Kept public so the
  /// Faces look can put its gripping hand on the same item without duplicating
  /// the aiming rules.
  static double heldAngle(
    SimulationBall ball, {
    PowerUpKind? weapon,
    int slot = 0,
  }) {
    final held = weapon ?? ball.held;
    final spread = ball.heldSecondary == null
        ? 0.0
        : (slot == 0 ? -0.32 : 0.32);
    if (held != null && ball.trackingItems.contains(held)) {
      return ball.shieldAngle + spread;
    }
    final target = ball.aimTarget;
    final Offset toward;
    if ((held?.isGun ?? false) && target != null) {
      toward = target.position - ball.position;
    } else if (ball.velocity != Offset.zero) {
      toward = ball.velocity;
    } else {
      toward = const Offset(1, 0);
    }
    return math.atan2(toward.dy, toward.dx) + spread;
  }

  /// Center of the held item's sprite. [gripInset] pulls it in along the
  /// aim (ball radii); [gripSide] moves it across the aim, to the ball's
  /// right for slot 0 and mirrored for the second hand (slot 1). A shield
  /// ignores both and keeps hugging the ball.
  static Offset heldCenter(
    SimulationBall ball, {
    PowerUpKind? weapon,
    int slot = 0,
    double? gripInset,
    double gripSide = 0,
  }) {
    final held = weapon ?? ball.held;
    final angle = heldAngle(ball, weapon: held, slot: slot);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final defaultInset = held?.isBlade == true ? 0.2 : 0.0;
    final inset = (gripInset ?? defaultInset).clamp(0.0, 1.5);
    final baseDistance = held == PowerUpKind.shield
        ? 1.0
        : held?.isBlade == true
        ? 2.0
        : held == PowerUpKind.hook || held == PowerUpKind.threadHarpoon
        ? 1.55
        : 1.2;
    final distance =
        ball.radius *
        (held == PowerUpKind.shield
            ? baseDistance
            : math.max(0.1, baseDistance - inset));
    final center = ball.position + dir * distance;
    if (held == PowerUpKind.shield || gripSide == 0) return center;
    final side = gripSide.clamp(-1.5, 1.5) * (slot == 1 ? -1 : 1);
    return center + Offset(-dir.dy, dir.dx) * (ball.radius * side);
  }

  /// The angle a held sprite is drawn at: the aim [angle] plus the skill's
  /// grip rotation in [rotationDegrees], mirrored when the sprite flips
  /// (it points left), so a slanted sprite is corrected on both sides.
  static double heldSpriteAngle(double angle, double rotationDegrees) {
    if (rotationDegrees == 0) return angle;
    final rad = rotationDegrees.clamp(-180.0, 180.0) * math.pi / 180;
    return math.cos(angle) < 0 ? angle - rad : angle + rad;
  }

  /// Yellow lightning streaks behind a ball while the Speed power-up is
  /// active. They are painted before the ball so the face and held item stay
  /// crisp in front. Cosmetic only - no random draws or simulation state.
  static void paintSpeedTrail(
    Canvas canvas,
    SimulationBall ball, {
    double displayScale = 1,
    bool useEffectSprite = true,
  }) {
    if (ball.speedLeft <= 0) return;
    final speed = ball.velocity.distance;
    if (speed == 0) return;
    final dir = ball.velocity / speed;
    final side = Offset(-dir.dy, dir.dx);
    final r = ball.radius * displayScale;
    final sprite = useEffectSprite
        ? SpriteRegistry.frame(
            PowerUpSprites.effectId(EffectSprite.speedStreak),
          )
        : null;
    if (sprite != null) {
      _drawEffect(
        canvas,
        sprite,
        ball.position - dir * r * 1.25,
        r * 1.65,
        math.atan2(dir.dy, dir.dx),
        opacity: 0.9,
        anchor: SpriteRegistry.anchor(
          PowerUpSprites.effectId(EffectSprite.speedStreak),
        ),
      );
    }
    final pulse = 0.85 + 0.15 * math.sin(ball.speedLeft * 0.45);
    final colors = [
      const Color(0xFFFFF176),
      const Color(0xFFFFD600),
      const Color(0xFFFF8F00),
    ];
    for (var i = 0; i < 3; i++) {
      final sideOffset = (i - 1) * r * 0.48;
      final start = ball.position - dir * (r * 0.72) + side * sideOffset;
      final length = r * (1.45 + i * 0.34) * pulse;
      final zig = (i.isEven ? 1.0 : -1.0) * r * 0.2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(
          (start - dir * (length * 0.34) + side * zig).dx,
          (start - dir * (length * 0.34) + side * zig).dy,
        )
        ..lineTo(
          (start - dir * (length * 0.68) - side * zig * 0.65).dx,
          (start - dir * (length * 0.68) - side * zig * 0.65).dy,
        )
        ..lineTo((start - dir * length).dx, (start - dir * length).dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * (0.13 - i * 0.015))
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.miter
          ..color = colors[i].withValues(alpha: 0.9 - i * 0.16),
      );
    }
  }

  /// Looks drawn over [ball]: a frozen ball gets an icy tint, and what it holds is drawn on it. A gun
  /// sits on its edge pointing at its target (or the way it moves), a knife points the way it moves, and
  /// a shield is held on the side it faces.
  static void paintBallEffects(
    Canvas canvas,
    SimulationBall ball, {
    int step = 0,
    bool Function(PowerUpKind kind, int slot)? useWeaponSprite,
    int Function(PowerUpKind kind, int slot)? artworkTint,
    bool Function(PowerUpKind kind)? useEffectSprite,
    double? incomingAttackAngle,
    int Function(PowerUpKind kind)? firedWeaponHoldLeft,
    double Function(PowerUpKind kind, int slot)? weaponDisplayScale,
    double Function(PowerUpKind kind)? effectDisplayScale,
    double Function(PowerUpKind kind, int slot)? weaponGripInset,
    double Function(PowerUpKind kind, int slot)? weaponGripSide,
    double Function(PowerUpKind kind, int slot)? weaponGripRotation,
    double Function(PowerUpKind kind)? skillRange,
    double Function(PowerUpKind kind)? handEffectScale,
    Color Function(PowerUpKind kind)? handEffectColor,
    PowerUpKind Function(PowerUpKind kind, int slot)? artworkKind,
  }) {
    if (ball.equippedWeapons.contains(PowerUpKind.orbitingFlail)) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.orbitingFlail, -1) ?? 0xFFFFFFFF,
      );
      try {
        final angle = flailOrbitAngle(step);
        final direction = Offset(math.cos(angle), math.sin(angle));
        final flail = orbitingFlailCenter(ball.position, ball.radius, step);
        for (var trail = 3; trail >= 1; trail--) {
          final oldAngle = flailOrbitAngle(step - trail * 2);
          final oldCenter =
              ball.position +
              Offset(math.cos(oldAngle), math.sin(oldAngle)) *
                  ball.radius *
                  2.25;
          canvas.drawCircle(
            oldCenter,
            ball.radius * (0.18 + trail * 0.035),
            Paint()
              ..color = const Color(
                0xFFB8C2CC,
              ).withValues(alpha: 0.22 - trail * 0.045),
          );
        }
        canvas.drawLine(
          ball.position + direction * ball.radius * 0.72,
          flail,
          Paint()
            ..color = const Color(0xFFB8C2CC)
            ..strokeWidth = math.max(2, ball.radius * 0.1),
        );
        final sprite =
            (useWeaponSprite?.call(
                  PowerUpKind.orbitingFlail,
                  ball.equippedWeapons.indexOf(PowerUpKind.orbitingFlail),
                ) ??
                true)
            ? PowerUpSprites.of(PowerUpKind.orbitingFlail)
            : null;
        if (sprite == null) {
          drawGlyph(
            canvas,
            PowerUpKind.orbitingFlail,
            flail,
            ball.radius *
                0.42 *
                (weaponDisplayScale?.call(
                      PowerUpKind.orbitingFlail,
                      ball.equippedWeapons.indexOf(PowerUpKind.orbitingFlail),
                    ) ??
                    1),
          );
        } else {
          // Spin the head independently while its center orbits the ball.
          _drawSprite(
            canvas,
            sprite,
            flail,
            ball.radius *
                0.9 *
                (weaponDisplayScale?.call(
                      PowerUpKind.orbitingFlail,
                      ball.equippedWeapons.indexOf(PowerUpKind.orbitingFlail),
                    ) ??
                    1),
            -step * 0.34,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.iconId(PowerUpKind.orbitingFlail),
            ),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.burningLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.molotov, -1) ?? 0xFFFFFFFF,
      );
      try {
        for (var i = 0; i < 3; i++) {
          final flame = useEffectSprite?.call(PowerUpKind.molotov) ?? true
              ? SpriteRegistry.frameAt(
                  PowerUpSprites.animId(AnimatedEffect.flame),
                  step,
                  offset: i,
                  stepsPerFrame: _burningFlameStepsPerFrame,
                )
              : null;
          final flicker = 0.5 + 0.5 * math.sin(step * 0.52 + i * 1.61);
          final base =
              ball.position +
              Offset(
                (i - 1) *
                    (ball.radius *
                        (effectDisplayScale?.call(PowerUpKind.molotov) ?? 1)) *
                    0.58,
                0,
              );
          if (flame != null) {
            _drawEffect(
              canvas,
              flame,
              base,
              (ball.radius *
                      (effectDisplayScale?.call(PowerUpKind.molotov) ?? 1)) *
                  (0.72 + flicker * 0.16),
              0,
              anchor: SpriteRegistry.anchor(
                PowerUpSprites.animId(AnimatedEffect.flame),
              ),
            );
            continue;
          }
          final fallbackFlicker = 0.22 + 0.08 * math.sin(step * 0.5 + i).abs();
          final tip =
              base -
              Offset(
                0,
                (ball.radius *
                        (effectDisplayScale?.call(PowerUpKind.molotov) ?? 1)) *
                    fallbackFlicker,
              );
          final side =
              (ball.radius *
                  (effectDisplayScale?.call(PowerUpKind.molotov) ?? 1)) *
              0.12;
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - side, base.dy)
              ..quadraticBezierTo(tip.dx, tip.dy, base.dx + side, base.dy)
              ..close(),
            Paint()
              ..color =
                  (i.isEven ? const Color(0xFFFF4B20) : const Color(0xFFFFD23F))
                      .withValues(alpha: 0.9),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.poisonLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.poisonSwamp, -1) ?? 0xFFFFFFFF,
      );
      try {
        final pulse = 0.45 + 0.18 * math.sin(step * 0.32);
        canvas.drawCircle(
          ball.position,
          (ball.radius *
                  (effectDisplayScale?.call(PowerUpKind.poisonSwamp) ?? 1)) *
              1.08,
          Paint()..color = const Color(0xFF79B928).withValues(alpha: pulse),
        );
        for (var i = 0; i < 4; i++) {
          final angle = step * 0.035 + i * math.pi / 2;
          canvas.drawCircle(
            ball.position +
                Offset.fromDirection(
                  angle,
                  (ball.radius *
                          (effectDisplayScale?.call(PowerUpKind.poisonSwamp) ??
                              1)) *
                      1.12,
                ),
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.poisonSwamp) ?? 1)) *
                0.1,
            Paint()..color = const Color(0xFFCAFF54),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.timeBubbleLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.timeBubble, -1) ?? 0xFFFFFFFF,
      );
      try {
        final range = skillRange?.call(PowerUpKind.timeBubble) ?? 3;
        final sprite = useEffectSprite?.call(PowerUpKind.timeBubble) ?? true
            ? SpriteRegistry.frame(
                PowerUpSprites.effectId(EffectSprite.timeBubble),
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            ball.position,
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.timeBubble) ?? 1)) *
                range,
            step * 0.012,
            opacity: 0.72,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.effectId(EffectSprite.timeBubble),
            ),
          );
        }
        canvas.drawCircle(
          ball.position,
          (ball.radius *
                  (effectDisplayScale?.call(PowerUpKind.timeBubble) ?? 1)) *
              range,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF58A6FF).withValues(alpha: 0.55),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.repulsorLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.repulsor, -1) ?? 0xFFFFFFFF,
      );
      try {
        canvas.drawCircle(
          ball.position,
          (ball.radius *
                  (effectDisplayScale?.call(PowerUpKind.repulsor) ?? 1)) *
              1.25,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFF6B35).withValues(alpha: 0.75),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.vampireLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.vampire, -1) ?? 0xFFFFFFFF,
      );
      try {
        canvas.drawArc(
          Rect.fromCircle(
            center: ball.position,
            radius:
                (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.vampire) ?? 1)) *
                1.18,
          ),
          -math.pi / 2,
          math.pi * 1.5,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFB1123B),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.mirrorCharges > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.mirror, -1) ?? 0xFFFFFFFF,
      );
      try {
        final angle = incomingAttackAngle ?? 0;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final sprite = (useEffectSprite?.call(PowerUpKind.mirror) ?? true)
            ? PowerUpSprites.of(PowerUpKind.mirror)
            : null;
        if (sprite != null) {
          _drawSprite(
            canvas,
            sprite,
            ball.position +
                direction *
                    (ball.radius *
                        (effectDisplayScale?.call(PowerUpKind.mirror) ?? 1)) *
                    1.16,
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.mirror) ?? 1)) *
                0.72,
            angle + math.pi / 2,
            iconAngle: -math.pi / 4,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.iconId(PowerUpKind.mirror),
            ),
          );
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: ball.position,
            radius:
                (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.mirror) ?? 1)) *
                1.35,
          ),
          angle - 1.1,
          2.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = const Color(0xFFC7F5FF),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.overchargeLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.overcharge, -1) ?? 0xFFFFFFFF,
      );
      try {
        final maximumPower =
            (useEffectSprite?.call(PowerUpKind.overcharge) ?? true)
            ? ArenaEffectLibrary.frame(ArenaEffectKind.maximumPower, step)
            : null;
        if (maximumPower != null) {
          _drawEffect(
            canvas,
            maximumPower,
            ball.position,
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.overcharge) ?? 1)) *
                2.5,
            0,
            opacity: 0.92,
            anchor: ArenaEffectLibrary.anchor(ArenaEffectKind.maximumPower),
          );
        }
        canvas.drawCircle(
          ball.position,
          (ball.radius *
              (effectDisplayScale?.call(PowerUpKind.overcharge) ?? 1)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(
              1.5,
              (ball.radius *
                      (effectDisplayScale?.call(PowerUpKind.overcharge) ?? 1)) *
                  0.1,
            )
            ..color = const Color(0xFFFFD000).withValues(alpha: 0.85),
        );
        for (var i = 0; i < 4; i++) {
          final a = i * math.pi / 2 + ball.overchargeLeft * 0.1;
          canvas.drawCircle(
            ball.position +
                Offset(math.cos(a), math.sin(a)) *
                    (ball.radius *
                        (effectDisplayScale?.call(PowerUpKind.overcharge) ??
                            1)) *
                    1.35,
            2.5,
            Paint()..color = const Color(0xFFFFD000),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.gremlinShots > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.gremlin, -1) ?? 0xFFFFFFFF,
      );
      try {
        canvas.drawCircle(
          ball.position,
          (ball.radius * (effectDisplayScale?.call(PowerUpKind.gremlin) ?? 1)) *
              1.12,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFF7ED957),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.magneticFieldLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.magneticField, -1) ?? 0xFFFFFFFF,
      );
      try {
        final pulse = 0.72 + 0.18 * math.sin(ball.magneticFieldLeft * 0.35);
        final radius =
            (ball.radius *
                (effectDisplayScale?.call(PowerUpKind.magneticField) ?? 1)) *
            2;
        final sprite = useEffectSprite?.call(PowerUpKind.magneticField) ?? true
            ? SpriteRegistry.frame(
                PowerUpSprites.effectId(EffectSprite.magneticField),
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            ball.position,
            radius,
            -step * 0.025,
            opacity: pulse,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.effectId(EffectSprite.magneticField),
            ),
          );
        }
        canvas.drawCircle(
          ball.position,
          radius,
          Paint()
            ..color = const Color(0xFF7B2CBF).withValues(alpha: 0.18 * pulse),
        );
        canvas.drawCircle(
          ball.position,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(
              2,
              (ball.radius *
                      (effectDisplayScale?.call(PowerUpKind.magneticField) ??
                          1)) *
                  0.12,
            )
            ..color = const Color(0xFFD66BFF).withValues(alpha: pulse),
        );
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3 + ball.magneticFieldLeft * 0.08;
          final point =
              ball.position + Offset(math.cos(angle), math.sin(angle)) * radius;
          canvas.drawCircle(
            point,
            math.max(
              1.5,
              (ball.radius *
                      (effectDisplayScale?.call(PowerUpKind.magneticField) ??
                          1)) *
                  0.09,
            ),
            Paint()..color = const Color(0xFFFF8CFF),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.goldenArmorHits > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.goldenArmor, -1) ?? 0xFFFFFFFF,
      );
      try {
        final sprite = useEffectSprite?.call(PowerUpKind.goldenArmor) ?? true
            ? SpriteRegistry.frame(
                PowerUpSprites.effectId(EffectSprite.goldenArmorHit),
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            ball.position,
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.goldenArmor) ?? 1)) *
                1.45,
            step * 0.018,
            opacity: 0.68,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.effectId(EffectSprite.goldenArmorHit),
            ),
          );
        }
        final armor = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(
            3,
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.goldenArmor) ?? 1)) *
                0.16,
          )
          ..color = const Color(0xFFFFD54F);
        canvas.drawArc(
          Rect.fromCircle(
            center: ball.position,
            radius:
                (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.goldenArmor) ?? 1)) *
                1.18,
          ),
          math.pi * 0.9,
          math.pi * 1.2,
          false,
          armor,
        );
        for (var i = 0; i < ball.goldenArmorHits; i++) {
          canvas.drawCircle(
            ball.position +
                Offset(
                  (i * 2 - 1) *
                      (ball.radius *
                          (effectDisplayScale?.call(PowerUpKind.goldenArmor) ??
                              1)) *
                      0.35,
                  -(ball.radius *
                          (effectDisplayScale?.call(PowerUpKind.goldenArmor) ??
                              1)) *
                      1.3,
                ),
            math.max(
              2,
              (ball.radius *
                      (effectDisplayScale?.call(PowerUpKind.goldenArmor) ??
                          1)) *
                  0.1,
            ),
            Paint()..color = const Color(0xFFFFF3A0),
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.frozenLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.freeze, -1) ?? 0xFFFFFFFF,
      );
      try {
        canvas.drawCircle(
          ball.position,
          (ball.radius * (effectDisplayScale?.call(PowerUpKind.freeze) ?? 1)),
          Paint()..color = const Color(0xFF9FE3FF).withValues(alpha: 0.45),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    if (ball.stickyGooLeft > 0) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(PowerUpKind.stickyGoo, -1) ?? 0xFFFFFFFF,
      );
      try {
        final sprite = useEffectSprite?.call(PowerUpKind.stickyGoo) ?? true
            ? SpriteRegistry.frame(
                PowerUpSprites.effectId(EffectSprite.stickyGoo),
              )
            : null;
        if (sprite != null) {
          _drawEffect(
            canvas,
            sprite,
            ball.position +
                Offset(
                  0,
                  (ball.radius *
                          (effectDisplayScale?.call(PowerUpKind.stickyGoo) ??
                              1)) *
                      0.65,
                ),
            (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.stickyGoo) ?? 1)) *
                1.1,
            0,
            opacity: 0.9,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.effectId(EffectSprite.stickyGoo),
            ),
          );
        }
        canvas.drawArc(
          Rect.fromCircle(
            center: ball.position,
            radius:
                (ball.radius *
                    (effectDisplayScale?.call(PowerUpKind.stickyGoo) ?? 1)) *
                1.05,
          ),
          0,
          math.pi,
          true,
          Paint()..color = const Color(0xFF65E34F).withValues(alpha: 0.8),
        );
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
    for (var slot = 0; slot < ball.equippedWeapons.length; slot++) {
      SkillArtworkTint.begin(
        canvas,
        artworkTint?.call(ball.equippedWeapons[slot], slot) ?? 0xFFFFFFFF,
      );
      try {
        final weapon = ball.equippedWeapons[slot];
        if (weapon != PowerUpKind.orbitingFlail) {
          _paintHeldWeapon(
            canvas,
            ball,
            weapon,
            slot,
            firedHoldLeft: firedWeaponHoldLeft?.call(weapon) ?? 0,
            useSprite: useWeaponSprite?.call(weapon, slot) ?? true,
            displayScale: weaponDisplayScale?.call(weapon, slot) ?? 1,
            gripInset: weaponGripInset?.call(weapon, slot),
            gripSide: weaponGripSide?.call(weapon, slot) ?? 0,
            gripRotation: weaponGripRotation?.call(weapon, slot) ?? 0,
            handEffectScale: handEffectScale?.call(weapon) ?? 1,
            handEffectColor: handEffectColor?.call(weapon),
            artwork: artworkKind?.call(weapon, slot) ?? weapon,
          );
        }
      } finally {
        SkillArtworkTint.end(canvas);
      }
    }
  }

  static double? incomingAttackAngle(
    SimulationState state,
    SimulationBall target,
  ) {
    if (target.mirrorCharges <= 0) return null;
    Projectile? nearest;
    var nearestDistance = double.infinity;
    for (final projectile
        in state.powerUps?.projectiles ?? const <Projectile>[]) {
      if (projectile.spent || identical(projectile.owner, target)) continue;
      final towardTarget = target.position - projectile.position;
      if (projectile.velocity.dx * towardTarget.dx +
              projectile.velocity.dy * towardTarget.dy <=
          0) {
        continue;
      }
      final distance = towardTarget.distanceSquared;
      if (distance < nearestDistance) {
        nearest = projectile;
        nearestDistance = distance;
      }
    }
    final projectile = nearest;
    if (projectile == null) return null;
    final incomingSide = projectile.position - target.position;
    return math.atan2(incomingSide.dy, incomingSide.dx);
  }

  static double flailOrbitAngle(int step) => step * 0.075;

  static Offset orbitingFlailCenter(
    Offset ballCenter,
    double ballRadius,
    int step,
  ) {
    final angle = flailOrbitAngle(step);
    return ballCenter +
        Offset(math.cos(angle), math.sin(angle)) * ballRadius * 2.25;
  }

  static void _paintHeldWeapon(
    Canvas canvas,
    SimulationBall ball,
    PowerUpKind held,
    int slot, {
    int firedHoldLeft = 0,
    bool useSprite = true,
    double displayScale = 1,
    double? gripInset,
    double gripSide = 0,
    double gripRotation = 0,
    double handEffectScale = 1,
    Color? handEffectColor,
    PowerUpKind? artwork,
  }) {
    // [artwork]: the weapon picture to show (a skill can look like another weapon); [held] keeps the
    // behavior-specific drawing.
    final art = artwork ?? held;
    // The active cast has its own charge orb and beam. Keeping the generated
    // weapon badge here covered the caster's face and looked like it vanished.
    if (held == PowerUpKind.energyWave && firedHoldLeft > 0) return;
    if (held == PowerUpKind.fireWall) {
      for (final side in const [-1.0, 1.0]) {
        final hand = ball.position + Offset(side * ball.radius * 0.82, 0);
        final flame = SpriteRegistry.frameAt(
          PowerUpSprites.animId(AnimatedEffect.flame),
          firedHoldLeft,
          offset: side > 0 ? 2 : 0,
        );
        if (flame != null) {
          _drawEffect(
            canvas,
            flame,
            hand - Offset(0, ball.radius * 0.2),
            ball.radius * 0.62 * handEffectScale * displayScale,
            0,
            anchor: SpriteRegistry.anchor(
              PowerUpSprites.animId(AnimatedEffect.flame),
            ),
          );
        } else {
          canvas.drawCircle(
            hand,
            ball.radius * 0.2 * displayScale,
            Paint()..color = handEffectColor ?? const Color(0xFFFF6422),
          );
        }
      }
      return;
    }
    final sprite = useSprite ? PowerUpSprites.of(art) : null;
    if (held == PowerUpKind.shield) {
      final angle = heldAngle(ball, weapon: held, slot: slot);
      canvas.drawArc(
        Rect.fromCircle(
          center: ball.position,
          radius: (ball.radius + 4) * displayScale,
        ),
        angle - 0.9,
        1.8,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = colorOf(PowerUpKind.shield),
      );
      if (sprite != null) {
        _drawSprite(
          canvas,
          sprite,
          heldCenter(ball, weapon: held, slot: slot, gripInset: gripInset),
          ball.radius * 0.7 * displayScale,
          angle +
              math.pi / 2 +
              gripRotation.clamp(-180.0, 180.0) * math.pi / 180,
          anchor: SpriteRegistry.anchor(PowerUpSprites.iconId(art)),
        );
      } else {
        drawGlyph(
          canvas,
          held,
          heldCenter(ball, weapon: held, slot: slot, gripInset: gripInset),
          ball.radius * 0.7 * displayScale,
        );
      }
      return;
    }
    if (sprite == null) {
      final badge = heldCenter(
        ball,
        weapon: held,
        slot: slot,
        gripInset: gripInset,
        gripSide: gripSide,
      );
      final r = math.max(
        6.0,
        ball.radius * (held.isBlade ? 0.72 : 0.36) * displayScale,
      );
      canvas.drawCircle(badge, r, Paint()..color = const Color(0xFF15151A));
      drawGlyph(canvas, art, badge, r * 0.62);
      return;
    }
    final baseAngle = heldAngle(ball, weapon: held, slot: slot);
    final firedProgress = firedHoldLeft <= 0 ? 0.0 : 1 - firedHoldLeft / 30.0;
    final drop = ((firedProgress - 0.35) / 0.65).clamp(0.0, 1.0);
    final angle = baseAngle + drop * 1.15 * (slot.isEven ? 1 : -1);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final center =
        heldCenter(
          ball,
          weapon: held,
          slot: slot,
          gripInset: gripInset,
          gripSide: gripSide,
        ) +
        Offset(
          math.sin(drop * math.pi) * ball.radius * 0.25,
          drop * drop * ball.radius * 2.2,
        );
    _drawSprite(
      canvas,
      sprite,
      center,
      ball.radius * (held.isBlade ? 1.8 : 0.9) * displayScale,
      heldSpriteAngle(angle, gripRotation),
      iconAngle: _iconAngle[art] ?? 0,
      flip: dir.dx < 0,
      opacity: 1 - drop * drop,
      anchor: SpriteRegistry.anchor(PowerUpSprites.iconId(art)),
    );
  }

  /// A simple flat glyph for [kind], about [s] in half-size, centered at [c] (also used for the
  /// weapons list in Match Setup).
  static void drawGlyph(Canvas canvas, PowerUpKind kind, Offset c, double s) {
    final color = colorOf(kind);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, s * 0.28)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    Offset at(double x, double y) => c + Offset(x * s, y * s);
    switch (kind) {
      case PowerUpKind.pistol:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.9, -0.5).dx, at(-0.9, -0.5).dy)
            ..lineTo(at(0.9, -0.5).dx, at(0.9, -0.5).dy)
            ..lineTo(at(0.9, -0.1).dx, at(0.9, -0.1).dy)
            ..lineTo(at(-0.2, -0.1).dx, at(-0.2, -0.1).dy)
            ..lineTo(at(-0.35, 0.8).dx, at(-0.35, 0.8).dy)
            ..lineTo(at(-0.85, 0.8).dx, at(-0.85, 0.8).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.shotgun:
        canvas.drawLine(at(-0.95, 0.35), at(0.95, -0.35), stroke);
        canvas.drawLine(at(-0.95, 0.35), at(-0.6, 0.75), stroke);
      case PowerUpKind.gatling:
        for (final y in [-0.45, 0.0, 0.45]) {
          canvas.drawLine(
            at(-0.8, y),
            at(0.9, y),
            stroke..strokeWidth = math.max(1.0, s * 0.2),
          );
        }
      case PowerUpKind.knife:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.9, 0.9).dx, at(-0.9, 0.9).dy)
            ..lineTo(at(0.9, -0.9).dx, at(0.9, -0.9).dy)
            ..lineTo(at(0.1, 0.1).dx, at(0.1, 0.1).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.shield:
        canvas.drawPath(
          Path()
            ..moveTo(at(0, -0.95).dx, at(0, -0.95).dy)
            ..lineTo(at(0.8, -0.6).dx, at(0.8, -0.6).dy)
            ..quadraticBezierTo(
              at(0.75, 0.55).dx,
              at(0.75, 0.55).dy,
              at(0, 0.95).dx,
              at(0, 0.95).dy,
            )
            ..quadraticBezierTo(
              at(-0.75, 0.55).dx,
              at(-0.75, 0.55).dy,
              at(-0.8, -0.6).dx,
              at(-0.8, -0.6).dy,
            )
            ..close(),
          fill,
        );
      case PowerUpKind.apple:
        canvas.drawCircle(
          at(0, 0.15),
          s * 0.75,
          Paint()..color = const Color(0xFFE53935),
        );
        canvas.drawLine(at(0, -0.55), at(0.35, -0.95), stroke);
      case PowerUpKind.speed:
        canvas.drawPath(
          Path()
            ..moveTo(at(0.2, -1).dx, at(0.2, -1).dy)
            ..lineTo(at(-0.55, 0.1).dx, at(-0.55, 0.1).dy)
            ..lineTo(at(0, 0.1).dx, at(0, 0.1).dy)
            ..lineTo(at(-0.25, 1).dx, at(-0.25, 1).dy)
            ..lineTo(at(0.6, -0.2).dx, at(0.6, -0.2).dy)
            ..lineTo(at(0.05, -0.2).dx, at(0.05, -0.2).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.freeze:
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          canvas.drawLine(
            at(math.cos(a), math.sin(a)),
            at(-math.cos(a), -math.sin(a)),
            stroke,
          );
        }
      case PowerUpKind.mine:
        canvas.drawCircle(
          at(-0.1, 0.2),
          s * 0.7,
          Paint()..color = const Color(0xFF2B2B33),
        );
        canvas.drawLine(
          at(0.35, -0.35),
          at(0.75, -0.85),
          Paint()
            ..strokeWidth = math.max(1.0, s * 0.2)
            ..color = const Color(0xFFFFB347),
        );
      case PowerUpKind.magnet:
        canvas.drawArc(
          Rect.fromCircle(center: at(0, 0.1), radius: s * 0.65),
          0,
          math.pi,
          false,
          stroke,
        );
        canvas.drawLine(at(-0.65, 0.1), at(-0.65, -0.8), stroke);
        canvas.drawLine(at(0.65, 0.1), at(0.65, -0.8), stroke);
      case PowerUpKind.grenade:
        canvas.drawOval(
          Rect.fromCenter(center: at(0, 0.2), width: s * 1.3, height: s * 1.5),
          fill,
        );
        canvas.drawLine(at(-0.2, -0.6), at(0.5, -0.9), stroke);
      case PowerUpKind.hook:
        canvas.drawLine(at(-0.9, 0), at(0.6, 0), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(at(0.95, 0).dx, at(0.95, 0).dy)
            ..lineTo(at(0.45, -0.45).dx, at(0.45, -0.45).dy)
            ..lineTo(at(0.45, 0.45).dx, at(0.45, 0.45).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.sword:
        canvas.drawLine(at(-0.85, 0.85), at(0.9, -0.9), stroke);
        canvas.drawLine(at(-0.75, 0.25), at(-0.25, 0.75), stroke);
      case PowerUpKind.ghost:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.75, 0.9).dx, at(-0.75, 0.9).dy)
            ..lineTo(at(-0.75, -0.1).dx, at(-0.75, -0.1).dy)
            ..arcToPoint(at(0.75, -0.1), radius: Radius.circular(s * 0.75))
            ..lineTo(at(0.75, 0.9).dx, at(0.75, 0.9).dy)
            ..lineTo(at(0.4, 0.6).dx, at(0.4, 0.6).dy)
            ..lineTo(at(0, 0.9).dx, at(0, 0.9).dy)
            ..lineTo(at(-0.4, 0.6).dx, at(-0.4, 0.6).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.portal:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: s * 1.2, height: s * 2),
          stroke..strokeWidth = math.max(1.4, s * 0.22),
        );
        canvas.drawArc(
          Rect.fromCenter(center: c, width: s * 0.7, height: s * 1.35),
          -math.pi / 2,
          math.pi,
          false,
          stroke..color = const Color(0xFFFF58D6),
        );
      case PowerUpKind.spikeWall:
        final path = Path()..moveTo(at(-1, 0.7).dx, at(-1, 0.7).dy);
        for (var i = 0; i < 4; i++) {
          path
            ..lineTo(at(-0.75 + i * 0.5, -0.85).dx, at(0, -0.85).dy)
            ..lineTo(at(-0.5 + i * 0.5, 0.7).dx, at(0, 0.7).dy);
        }
        canvas.drawPath(path, fill);
      case PowerUpKind.goldenArmor:
        canvas.drawPath(
          Path()
            ..moveTo(at(-0.85, 0.55).dx, at(-0.85, 0.55).dy)
            ..lineTo(at(-0.65, -0.75).dx, at(-0.65, -0.75).dy)
            ..lineTo(at(0, -1).dx, at(0, -1).dy)
            ..lineTo(at(0.65, -0.75).dx, at(0.65, -0.75).dy)
            ..lineTo(at(0.85, 0.55).dx, at(0.85, 0.55).dy)
            ..close(),
          fill,
        );
      case PowerUpKind.bow:
        canvas.drawArc(
          Rect.fromCenter(center: c, width: s * 1.2, height: s * 2),
          -math.pi / 2,
          math.pi,
          false,
          stroke,
        );
        canvas.drawLine(at(0, -1), at(0, 1), stroke);
        canvas.drawLine(at(-0.7, 0), at(0.85, 0), stroke);
        canvas.drawLine(at(0.85, 0), at(0.45, -0.28), stroke);
        canvas.drawLine(at(0.85, 0), at(0.45, 0.28), stroke);
      case PowerUpKind.stickyGoo:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: s * 2, height: s * 1.1),
          Paint()..color = const Color(0xFF65E34F),
        );
        canvas.drawCircle(
          at(-0.35, -0.1),
          s * 0.18,
          Paint()..color = const Color(0xFFB5FF73),
        );
        canvas.drawCircle(
          at(0.35, 0.15),
          s * 0.13,
          Paint()..color = const Color(0xFF287A2C),
        );
      default:
        canvas.drawCircle(c, s * 0.82, stroke);
        canvas.drawLine(at(-0.5, -0.5), at(0.5, 0.5), stroke);
        canvas.drawLine(at(0.5, -0.5), at(-0.5, 0.5), stroke);
    }
  }
}
