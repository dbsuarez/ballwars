import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import 'power_up_sprites.dart';

/// Draws the power-up layer of an Arsenal / All-Out match in the arena's coordinates (center at 0, 0):
/// pulsing field power-ups, armed mines, aim lines, bullets, blasts and knife slashes ([paint]), plus the
/// per-ball looks ([paintBallEffects]: the held weapon or shield on the ball, frozen tint).
///
/// Flat style and cheap to draw (see CLAUDE.md "Painting performance"): no blur filters, icons are
/// pixel-art images ([PowerUpSprites]), bullets are one batched drawRawPoints call.
class PowerUpPainter {
  PowerUpPainter._();

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
  }) {
    final p = state.powerUps;
    if (p == null) return;
    final r = p.fieldRadius;

    for (final e in p.explosions) {
      final t = e.age / PowerUpTuning.explosionShowSteps;
      final fade = (1 - t).clamp(0.0, 1.0);
      if (showEffects) {
        canvas.drawCircle(
          e.position,
          e.radius,
          Paint()
            ..color = const Color(0xFFFFB347).withValues(alpha: 0.25 * fade),
        );
      }
      canvas.drawCircle(
        e.position,
        e.radius * (0.6 + 0.4 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFF7A3D).withValues(alpha: fade),
      );
    }

    for (final flash in p.portalFlashes) {
      final t = flash.age / PowerUpTuning.explosionShowSteps;
      final fade = (1 - t).clamp(0.0, 1.0);
      final portalPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, r * 0.18)
        ..color = colorOf(PowerUpKind.portal).withValues(alpha: fade);
      for (final spot in [flash.from, flash.to]) {
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
    }

    for (final item in p.field) {
      // Subtle pulse: the token breathes about once a second.
      final pulse =
          0.5 +
          0.5 * math.sin((state.step - item.spawnStep) * 2 * math.pi / 60);
      _paintToken(
        canvas,
        item.kind,
        item.position,
        r * (0.96 + 0.08 * pulse),
        0.5 + 0.5 * pulse,
      );
    }

    for (final wall in p.spikeWalls) {
      final radial = Offset(math.cos(wall.angle), math.sin(wall.angle));
      final tangent = Offset(-radial.dy, radial.dx);
      final spacing = r * 0.96;
      final start = -(wall.spikeCount - 1) / 2;
      for (var i = 0; i < wall.spikeCount; i++) {
        final base = wall.position + tangent * ((start + i) * spacing);
        final left = base - tangent * r * 0.42 + radial * r * 0.38;
        final right = base + tangent * r * 0.42 + radial * r * 0.38;
        final tip = base - radial * r * 0.9;
        canvas.drawPath(
          Path()
            ..moveTo(left.dx, left.dy)
            ..lineTo(tip.dx, tip.dy)
            ..lineTo(right.dx, right.dy)
            ..close(),
          Paint()..color = colorOf(PowerUpKind.spikeWall),
        );
        canvas.drawLine(
          left,
          right,
          Paint()
            ..strokeWidth = math.max(1.5, r * 0.12)
            ..color = const Color(0xFF681F2A),
        );
      }
    }

    for (final bomb in p.mines) {
      // Armed: ringed in its owner's color, with a red light blinking twice a second.
      final blink = ((state.step - bomb.armedStep) ~/ 15).isEven;
      _paintToken(
        canvas,
        bomb.kind,
        bomb.position,
        r,
        bomb.kind == PowerUpKind.phaseMine ? 0.18 : 1,
        ring: bomb.owner.config.primaryColor,
      );
      canvas.drawCircle(
        bomb.position + Offset(r * 0.62, -r * 0.62),
        math.max(2.5, r * 0.18),
        Paint()
          ..color = blink ? const Color(0xFFFF3B30) : const Color(0xFF5A1A16),
      );
    }

    for (final ball in state.balls) {
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
    }

    if (p.projectiles.isNotEmpty) {
      // Bullets: a faint trail, a brass casing and a copper tip along the flight direction, each layer one
      // batched call.
      final trail = Float32List(p.projectiles.length * 4);
      final casing = Float32List(p.projectiles.length * 4);
      final tip = Float32List(p.projectiles.length * 4);
      var n = 0;
      final len = math.max(6.0, r * 0.6);
      for (final shot in p.projectiles) {
        if (shot.kind == PowerUpKind.hook) {
          // The hook flying out on its chain.
          _paintChain(canvas, shot.owner.position, shot.position);
          final sprite = PowerUpSprites.of(PowerUpKind.hook);
          final angle = math.atan2(shot.velocity.dy, shot.velocity.dx);
          if (sprite == null) {
            drawGlyph(canvas, PowerUpKind.hook, shot.position, r * 0.6);
          } else {
            _drawSprite(
              canvas,
              sprite,
              shot.position,
              r * 0.8,
              angle,
              flip: shot.velocity.dx < 0,
            );
          }
          continue;
        }
        if (shot.landAt != null) {
          // A grenade in flight: its icon, tumbling.
          final sprite = PowerUpSprites.of(PowerUpKind.grenade);
          if (sprite == null) {
            canvas.drawCircle(
              shot.position,
              r * 0.4,
              Paint()..color = colorOf(PowerUpKind.grenade),
            );
          } else {
            _drawSprite(
              canvas,
              sprite,
              shot.position,
              r * 0.6,
              state.step * 0.3,
            );
          }
          continue;
        }
        if (shot.kind == PowerUpKind.freeze) {
          _paintIceWave(canvas, shot, r);
          continue;
        }
        final speed = shot.velocity.distance;
        if (speed == 0) continue;
        final dir = shot.velocity / speed;
        final front = shot.position;
        final mid = front - dir * (len * 0.45);
        final back = front - dir * len;
        final tail = front - dir * (len * 3.5);
        void put(Float32List list, Offset a, Offset b) {
          list
            ..[n] = a.dx
            ..[n + 1] = a.dy
            ..[n + 2] = b.dx
            ..[n + 3] = b.dy;
        }

        put(trail, tail, back);
        put(casing, back, mid);
        put(tip, mid, front);
        n += 4;
      }
      if (n > 0) {
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(trail, 0, n),
          _trailPaint..strokeWidth = len * 0.35,
        );
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(casing, 0, n),
          _casingPaint..strokeWidth = len * 0.5,
        );
        canvas.drawRawPoints(
          ui.PointMode.lines,
          Float32List.sublistView(tip, 0, n),
          _tipPaint..strokeWidth = len * 0.5,
        );
      }
    }

    // Hooked balls on their chain, being reeled in.
    for (final h in p.pulls) {
      _paintChain(canvas, h.owner.position, h.target.position);
    }

    for (final m in p.slashMarks) {
      // Two quick strokes across the cut, fading out.
      final fade = (1 - m.age / PowerUpTuning.slashShowSteps).clamp(0.0, 1.0);
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
    }
  }

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
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF4F4F2));
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
    final sprite = PowerUpSprites.of(kind);
    if (sprite == null) {
      drawGlyph(canvas, kind, c, r * 0.62);
    } else {
      _drawSprite(canvas, sprite, c, r * 0.68, 0);
    }
  }

  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;

  /// Draws [image] centered at [c], [half] in half-size. The icon is first turned so its own direction
  /// [iconAngle] lies along +x, then mirrored top-to-bottom if [flip] (so a gun pointing left isn't upside
  /// down), then turned to [rotation].
  static void _drawSprite(
    Canvas canvas,
    ui.Image image,
    Offset c,
    double half,
    double rotation, {
    double iconAngle = 0,
    bool flip = false,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (flip) canvas.scale(1, -1);
    if (iconAngle != 0) canvas.rotate(-iconAngle);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: 2 * half, height: 2 * half),
      _spritePaint,
    );
    canvas.restore();
  }

  /// The direction, in radians, each weapon icon points in as drawn in its SVG (guns: the muzzle; knife:
  /// the tip). Weapons are turned from it to point where they are used.
  static const Map<PowerUpKind, double> _iconAngle = {
    PowerUpKind.knife: -math.pi / 4,
    PowerUpKind.sword: -math.pi / 4,
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
    if (held == PowerUpKind.shield) return ball.shieldAngle + spread;
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

  /// Center of the held item's sprite.
  static Offset heldCenter(
    SimulationBall ball, {
    PowerUpKind? weapon,
    int slot = 0,
  }) {
    final held = weapon ?? ball.held;
    final angle = heldAngle(ball, weapon: held, slot: slot);
    final dir = Offset(math.cos(angle), math.sin(angle));
    final distance = held == PowerUpKind.shield
        ? ball.radius
        : ball.radius * 1.2;
    return ball.position + dir * distance;
  }

  /// Yellow lightning streaks behind a ball while the Speed power-up is
  /// active. They are painted before the ball so the face and held item stay
  /// crisp in front. Cosmetic only - no random draws or simulation state.
  static void paintSpeedTrail(Canvas canvas, SimulationBall ball) {
    if (ball.speedLeft <= 0) return;
    final speed = ball.velocity.distance;
    if (speed == 0) return;
    final dir = ball.velocity / speed;
    final side = Offset(-dir.dy, dir.dx);
    final r = ball.radius;
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
  static void paintBallEffects(Canvas canvas, SimulationBall ball) {
    if (ball.timeBubbleLeft > 0) {
      canvas.drawCircle(
        ball.position,
        ball.radius * 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF58A6FF).withValues(alpha: 0.55),
      );
    }
    if (ball.repulsorLeft > 0) {
      canvas.drawCircle(
        ball.position,
        ball.radius * 1.25,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFF6B35).withValues(alpha: 0.75),
      );
    }
    if (ball.vampireLeft > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: ball.position, radius: ball.radius * 1.18),
        -math.pi / 2,
        math.pi * 1.5,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFB1123B),
      );
    }
    if (ball.mirrorCharges > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: ball.position, radius: ball.radius * 1.35),
        -1.1,
        2.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFC7F5FF),
      );
    }
    if (ball.overchargeLeft > 0) {
      for (var i = 0; i < 4; i++) {
        final a = i * math.pi / 2 + ball.overchargeLeft * 0.1;
        canvas.drawCircle(
          ball.position + Offset(math.cos(a), math.sin(a)) * ball.radius * 1.35,
          2.5,
          Paint()..color = const Color(0xFFFFD000),
        );
      }
    }
    if (ball.gremlinShots > 0) {
      canvas.drawCircle(
        ball.position,
        ball.radius * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF7ED957),
      );
    }
    if (ball.magneticFieldLeft > 0) {
      final pulse = 0.72 + 0.18 * math.sin(ball.magneticFieldLeft * 0.35);
      final radius = ball.radius * 2;
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
          ..strokeWidth = math.max(2, ball.radius * 0.12)
          ..color = const Color(0xFFD66BFF).withValues(alpha: pulse),
      );
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + ball.magneticFieldLeft * 0.08;
        final point =
            ball.position + Offset(math.cos(angle), math.sin(angle)) * radius;
        canvas.drawCircle(
          point,
          math.max(1.5, ball.radius * 0.09),
          Paint()..color = const Color(0xFFFF8CFF),
        );
      }
    }
    if (ball.goldenArmorHits > 0) {
      final armor = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, ball.radius * 0.16)
        ..color = const Color(0xFFFFD54F);
      canvas.drawArc(
        Rect.fromCircle(center: ball.position, radius: ball.radius * 1.18),
        math.pi * 0.9,
        math.pi * 1.2,
        false,
        armor,
      );
      for (var i = 0; i < ball.goldenArmorHits; i++) {
        canvas.drawCircle(
          ball.position +
              Offset((i * 2 - 1) * ball.radius * 0.35, -ball.radius * 1.3),
          math.max(2, ball.radius * 0.1),
          Paint()..color = const Color(0xFFFFF3A0),
        );
      }
    }
    if (ball.frozenLeft > 0) {
      canvas.drawCircle(
        ball.position,
        ball.radius,
        Paint()..color = const Color(0xFF9FE3FF).withValues(alpha: 0.45),
      );
    }
    for (var slot = 0; slot < ball.equippedWeapons.length; slot++) {
      _paintHeldWeapon(canvas, ball, ball.equippedWeapons[slot], slot);
    }
  }

  static void _paintHeldWeapon(
    Canvas canvas,
    SimulationBall ball,
    PowerUpKind held,
    int slot,
  ) {
    final sprite = PowerUpSprites.of(held);
    if (held == PowerUpKind.shield) {
      final angle = heldAngle(ball, weapon: held, slot: slot);
      canvas.drawArc(
        Rect.fromCircle(center: ball.position, radius: ball.radius + 4),
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
          heldCenter(ball, weapon: held, slot: slot),
          ball.radius * 0.7,
          angle + math.pi / 2,
        );
      }
      return;
    }
    if (sprite == null) {
      final badge = heldCenter(ball, weapon: held, slot: slot);
      final r = math.max(6.0, ball.radius * 0.36);
      canvas.drawCircle(badge, r, Paint()..color = const Color(0xFF15151A));
      drawGlyph(canvas, held, badge, r * 0.62);
      return;
    }
    final angle = heldAngle(ball, weapon: held, slot: slot);
    final dir = Offset(math.cos(angle), math.sin(angle));
    _drawSprite(
      canvas,
      sprite,
      heldCenter(ball, weapon: held, slot: slot),
      ball.radius * 0.9,
      angle,
      iconAngle: _iconAngle[held] ?? 0,
      flip: dir.dx < 0,
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
      default:
        canvas.drawCircle(c, s * 0.82, stroke);
        canvas.drawLine(at(-0.5, -0.5), at(0.5, 0.5), stroke);
        canvas.drawLine(at(0.5, -0.5), at(-0.5, 0.5), stroke);
    }
  }
}
