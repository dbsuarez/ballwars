import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../domain/simulation_state.dart';
import '../domain/floating_text.dart';
import '../domain/simulation_ball.dart';
import '../domain/particle_system.dart';
import 'ball_face_painter.dart';
import 'power_up_painter.dart';
import 'ball_face_expression.dart';
import '../../match_setup/domain/match_config.dart';
import '../../settings/domain/app_settings.dart';

class ArenaPainter extends CustomPainter {
  final SimulationState state;
  final double arenaRadius;
  final double? worldRadius;
  final double? rimInset;
  final double rimAngle;

  /// Sparks and particles. Off only hides them: they are still simulated,
  /// so the match plays out the same either way.
  final bool showEffects;
  final bool showBallGlow;
  final String arenaTitle;
  final String arenaSubtitle;
  final WallSparkSize wallSparkSize;
  final ArenaDecoration arenaDecoration;
  final bool handsOnPictures;
  final bool whitePickupBackgrounds;
  final EffectRenderMode projectileRenderMode;
  final EffectRenderMode explosionRenderMode;
  final EffectRenderMode freezeRenderMode;

  /// The theme's background (inside the arena) and text color (the rim).
  final Color background;
  final Color rimColor;

  static const double _ballGlowPadding = 4.0;
  static const double _rimMargin = 10.0;

  ArenaPainter({
    required this.state,
    required this.arenaRadius,
    this.worldRadius,
    this.rimInset,
    required this.rimAngle,
    this.showEffects = true,
    this.showBallGlow = true,
    this.arenaTitle = 'dbsuarez',
    this.arenaSubtitle = 'bakbakan na',
    this.wallSparkSize = WallSparkSize.normal,
    this.arenaDecoration = ArenaDecoration.defaultArena,
    this.handsOnPictures = false,
    this.whitePickupBackgrounds = true,
    this.projectileRenderMode = EffectRenderMode.sprite,
    this.explosionRenderMode = EffectRenderMode.sprite,
    this.freezeRenderMode = EffectRenderMode.sprite,
    this.background = const Color(0xFF0A0A0B),
    this.rimColor = const Color(0xFFF2F2F0),
    this.look = BallLook.pictures,
    super.repaint,
  });

  /// Pictures, or smiley faces (cosmetic).
  final BallLook look;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room for the rim's stroke and glow so they aren't clipped at the edges.
    final scale = rimInset == null
        ? size.shortestSide / (2 * ((worldRadius ?? arenaRadius) + _rimMargin))
        : (size.shortestSide - 2 * rimInset!) /
              (2 * (worldRadius ?? arenaRadius));

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    _paintBackground(canvas);
    _paintRim(canvas);
    _paintFanLines(canvas);
    _paintBeamAttack(canvas);
    PowerUpPainter.paint(
      canvas,
      state,
      arenaRadius,
      showEffects: showEffects,
      whitePickupBackgrounds: whitePickupBackgrounds,
      projectileRenderMode: projectileRenderMode,
      explosionRenderMode: explosionRenderMode,
      freezeRenderMode: freezeRenderMode,
    );
    if (showEffects) _paintParticles(canvas);
    // Depth order: sort balls by distance from center (farthest drawn first = behind)
    final sortedBalls = List<SimulationBall>.from(state.balls)
      ..sort((a, b) => b.position.distance.compareTo(a.position.distance));
    for (final ball in sortedBalls) {
      if (ball.isEliminated) continue;
      _paintSingleBall(canvas, ball);
    }
    _paintFloatingText(canvas);

    canvas.restore();
  }

  void _paintBackground(Canvas canvas) {
    final visibleRadius = state.arenaRadius;
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(Rect.fromCircle(center: Offset.zero, radius: visibleRadius)),
    );
    switch (arenaDecoration) {
      case ArenaDecoration.defaultArena:
        _paintDefaultFloor(canvas, visibleRadius);
      case ArenaDecoration.space:
        _paintSpaceFloor(canvas, visibleRadius);
      case ArenaDecoration.desert:
        _paintDesertFloor(canvas, visibleRadius);
      case ArenaDecoration.wilderness:
        _paintWildernessFloor(canvas, visibleRadius);
      case ArenaDecoration.neonGrid:
        _paintNeonFloor(canvas, visibleRadius);
    }
    canvas.restore();
    _paintArenaText(canvas);
  }

  void _paintDefaultFloor(Canvas canvas, double visibleRadius) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(Offset.zero, visibleRadius, [
        Color.lerp(background, rimColor, 0.05)!,
        background,
      ]);
    canvas.drawCircle(Offset.zero, visibleRadius, paint);
    _paintGrid(canvas);
  }

  void _paintSpaceFloor(Canvas canvas, double radius) {
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-radius * 0.25, -radius * 0.3),
          radius * 1.35,
          const [Color(0xFF18245A), Color(0xFF050611)],
        ),
    );
    canvas.drawCircle(
      Offset(radius * 0.25, radius * 0.1),
      radius * 0.55,
      Paint()..color = const Color(0xFF8B5CF6).withValues(alpha: 0.12),
    );
    final star = Paint()..color = const Color(0xFFE7F7FF);
    for (var i = 0; i < 80; i++) {
      final x = math.sin(i * 91.17) * radius * 0.92;
      final y = math.cos(i * 47.31) * radius * 0.92;
      canvas.drawCircle(Offset(x, y), i % 9 == 0 ? 1.8 : 0.8, star);
    }
  }

  void _paintDesertFloor(Canvas canvas, double radius) {
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFFC88746),
    );
    final dune = Paint()
      ..color = const Color(0xFFF0C276).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16;
    for (var i = -2; i <= 2; i++) {
      final y = i * radius * 0.35;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(i.isEven ? -radius * 0.25 : radius * 0.25, y),
          width: radius * 1.7,
          height: radius * 0.55,
        ),
        math.pi * 0.08,
        math.pi * 0.84,
        false,
        dune,
      );
    }
    final grain = Paint()
      ..color = const Color(0xFF7A4828).withValues(alpha: 0.28);
    for (var i = 0; i < 55; i++) {
      canvas.drawCircle(
        Offset(
          math.sin(i * 17.3) * radius * 0.9,
          math.cos(i * 33.7) * radius * 0.9,
        ),
        1.1,
        grain,
      );
    }
  }

  void _paintWildernessFloor(Canvas canvas, double radius) {
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, radius, const [
          Color(0xFF315B37),
          Color(0xFF102A1B),
        ]),
    );
    final rings = Paint()
      ..color = const Color(0xFF9CCC65).withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 1; i <= 6; i++) {
      canvas.drawCircle(Offset.zero, radius * i / 7, rings);
    }
    final leaves = Paint()
      ..color = const Color(0xFFB7D66A).withValues(alpha: 0.35);
    for (var i = 0; i < 32; i++) {
      final at = Offset(math.sin(i * 13.7), math.cos(i * 29.1)) * radius * 0.82;
      canvas.drawOval(Rect.fromCenter(center: at, width: 9, height: 4), leaves);
    }
  }

  void _paintNeonFloor(Canvas canvas, double radius) {
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = const Color(0xFF050912),
    );
    final grid = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
      ..strokeWidth = 1.5;
    final step = radius / 6;
    for (var i = -6; i <= 6; i++) {
      canvas.drawLine(
        Offset(i * step, -radius),
        Offset(i * step, radius),
        grid,
      );
      canvas.drawLine(
        Offset(-radius, i * step),
        Offset(radius, i * step),
        grid,
      );
    }
    canvas.drawCircle(
      Offset.zero,
      radius * 0.62,
      Paint()
        ..color = const Color(0xFFFF2BD6).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }

  void _paintArenaText(Canvas canvas) {
    void line(String text, double size, double y, FontWeight weight) {
      if (text.trim().isEmpty) return;
      final painter = TextPainter(
        text: TextSpan(
          text: text.trim(),
          style: TextStyle(
            color: rimColor.withValues(alpha: 0.14),
            fontSize: size,
            fontWeight: weight,
            letterSpacing: size * 0.06,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: arenaRadius * 1.45);
      painter.paint(canvas, Offset(-painter.width / 2, y - painter.height / 2));
    }

    line(arenaTitle, arenaRadius * 0.14, -arenaRadius * 0.08, FontWeight.w900);
    line(
      arenaSubtitle,
      arenaRadius * 0.065,
      arenaRadius * 0.08,
      FontWeight.w600,
    );
  }

  /// Squares across the arena floor, [gridCells] across the diameter.
  static const int gridCells = 16;

  // Grid line endpoints per arena radius (each line is a chord, so no clip is needed).
  static final Map<double, Float32List> _gridCache = {};

  /// A faint square grid on the floor: one batched drawRawPoints call, chords cached per arena size.
  void _paintGrid(Canvas canvas) {
    final points = _gridCache[arenaRadius] ??= () {
      final r = arenaRadius;
      final step = 2 * r / gridCells;
      final list = <double>[];
      for (var i = 1; i < gridCells; i++) {
        final x = -r + i * step;
        final half = math.sqrt(math.max(0, r * r - x * x));
        list
          ..addAll([x, -half, x, half])
          ..addAll([-half, x, half, x]);
      }
      return Float32List.fromList(list);
    }();
    canvas.drawRawPoints(
      ui.PointMode.lines,
      points,
      Paint()
        ..strokeWidth = 1
        ..color = rimColor.withValues(alpha: 0.06),
    );
  }

  // Performance: no blur filters anywhere in the arena (they are among the
  // most expensive things a phone GPU draws, every frame). Glows are faked
  // with wider translucent strokes or radial gradients, sparks are plain dots.

  void _paintRim(Canvas canvas) {
    final visibleRadius = state.arenaRadius;
    // A soft halo (two wide translucent strokes) under the crisp rim.
    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..color = rimColor.withValues(alpha: 0.12);
    canvas.drawCircle(Offset.zero, visibleRadius, halo..strokeWidth = 6.5);
    canvas.drawCircle(Offset.zero, visibleRadius, halo..strokeWidth = 4.5);
    canvas.drawCircle(
      Offset.zero,
      visibleRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = rimColor,
    );
  }

  /// Paints every ball's lines: rim anchor to the owner's center. One batch
  /// of plain line segments per ball (drawRawPoints): far cheaper than a
  /// stroked path, which has to be tessellated on the CPU every frame.
  void _paintFanLines(Canvas canvas) {
    for (final ball in state.balls) {
      if (ball.isEliminated || ball.fanLines.isEmpty) continue;

      final points = Float32List(ball.fanLines.length * 4);
      var n = 0;
      for (final line in ball.fanLines) {
        if (!line.isActive) continue;
        points[n++] = line.startPoint.dx;
        points[n++] = line.startPoint.dy;
        points[n++] = ball.position.dx;
        points[n++] = ball.position.dy;
      }
      if (n == 0) continue;

      final paint = Paint()
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.butt
        ..color = ball.config.primaryColor.withValues(alpha: 0.85);
      canvas.drawRawPoints(
        ui.PointMode.lines,
        n == points.length ? points : Float32List.sublistView(points, 0, n),
        paint,
      );
    }
  }

  void _paintBeamAttack(Canvas canvas) {
    if (state.beamPhase == 0 ||
        state.beamFirer == null ||
        state.beamTarget == null) {
      return;
    }

    final firer = state.beamFirer!;
    final target = state.beamTarget!;

    // Beam direction from firer to target
    final beamAngle = math.atan2(
      target.position.dy - firer.position.dy,
      target.position.dx - firer.position.dx,
    );

    // Extend ray past target to arena rim
    final endPt = Offset(
      math.cos(beamAngle) * arenaRadius,
      math.sin(beamAngle) * arenaRadius,
    );

    Color beamColor;
    double alpha;
    double strokeWidth;

    switch (state.beamPhase) {
      case 1: // Solid ray
        beamColor = firer.config.primaryColor;
        alpha = 1.0;
        strokeWidth = 1.0;
        break;
      case 2: // Dotted ray
        beamColor = firer.config.primaryColor;
        alpha = 0.7;
        strokeWidth = 1.0;
        break;
      case 3: // Haze
        beamColor = firer.config.primaryColor;
        alpha = 0.3;
        strokeWidth = 2.0;
        break;
      default:
        return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = beamColor.withValues(alpha: alpha);

    if (state.beamPhase == 2) {
      // Dotted line - draw segments
      const segmentLength = 8.0;
      const gapLength = 8.0;
      double distance = 0.0;
      final totalLength = (endPt - firer.position).distance;

      while (distance < totalLength) {
        final startRatio = distance / totalLength;
        final endRatio = (distance + segmentLength) / totalLength;
        if (endRatio > 1.0) break;

        final startPt = Offset.lerp(firer.position, endPt, startRatio)!;
        final endPtSeg = Offset.lerp(firer.position, endPt, endRatio)!;
        canvas.drawLine(startPt, endPtSeg, paint);

        distance += segmentLength + gapLength;
      }
    } else {
      // Solid or haze - draw full line
      canvas.drawLine(firer.position, endPt, paint);
    }

    // Target keeps small cone while pinned (phase 1-3)
    if (state.beamPhase <= 3 && state.beamPhase > 0) {
      _paintTargetCone(canvas, target, beamAngle);
    }
  }

  void _paintTargetCone(
    Canvas canvas,
    SimulationBall target,
    double beamAngle,
  ) {
    // Small cone at target (opposite direction of beam)
    final coneAngle = beamAngle + math.pi;
    final halfWidth = 0.15; // Small fixed width

    final path = Path();
    path.moveTo(target.position.dx, target.position.dy);
    final rimAngle1 = coneAngle - halfWidth;
    final rimPt1 = Offset(
      math.cos(rimAngle1) * arenaRadius,
      math.sin(rimAngle1) * arenaRadius,
    );
    path.lineTo(rimPt1.dx, rimPt1.dy);
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: arenaRadius),
      rimAngle1,
      halfWidth * 2,
      false,
    );
    path.lineTo(target.position.dx, target.position.dy);
    path.close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = target.config.primaryColor.withValues(alpha: 0.4);
    canvas.drawPath(path, paint);
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      if (particle is Particle) {
        final lifeRatio =
            1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
        final hotness = (lifeRatio * 1.6).clamp(0.0, 1.0);
        final sparkColor = Color.lerp(particle.color, Colors.white, hotness)!;
        final sizeScale = particle.kind == ParticleKind.wallSpark
            ? wallSparkSize.scale
            : 1.0;
        canvas.drawCircle(
          particle.position,
          particle.baseRadius * lifeRatio * sizeScale,
          Paint()..color = sparkColor.withValues(alpha: lifeRatio),
        );
      } else if (particle is RimArcParticle) {
        // Render thin white arc along rim
        final (startPt, endPt) = particle.getArcSegment();
        final lifeRatio =
            1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withValues(alpha: lifeRatio);
        canvas.drawLine(startPt, endPt, paint);
      }
    }
  }

  void _paintSingleBall(Canvas canvas, SimulationBall ball) {
    if (ball.isEliminated) return;
    // A ghost is drawn see-through (a layer only while the effect lasts, which is rare).
    if (ball.isGhost) {
      canvas.saveLayer(
        // Room for the held weapon, drawn just past the edge.
        Rect.fromCircle(
          center: ball.position,
          radius: ball.radius * 2 + _ballGlowPadding,
        ),
        Paint()..color = const Color(0x66000000),
      );
    }

    PowerUpPainter.paintSpeedTrail(canvas, ball);

    if (showBallGlow) {
      canvas.drawCircle(
        ball.position,
        ball.radius + 4,
        Paint()..color = ball.config.glowColor.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        ball.position,
        ball.radius + 2,
        Paint()..color = ball.config.glowColor.withValues(alpha: 0.28),
      );
    }

    if (look == BallLook.faces) {
      paintSmiley(canvas, ball, faceHealth(ball), state.balls);
    } else {
      BallFacePainter.paint(
        canvas,
        ball.position,
        ball.radius,
        ball.config,
        ball.cachedUiImage,
      );
      if (look == BallLook.both) {
        paintSmiley(
          canvas,
          ball,
          faceHealth(ball),
          state.balls,
          backgroundAlpha: 0.38,
        );
      }
    }
    PowerUpPainter.paintBallEffects(
      canvas,
      ball,
      step: state.step,
      incomingAttackAngle: PowerUpPainter.incomingAttackAngle(state, ball),
      firedWeaponHoldLeft: (kind) =>
          state.powerUps?.firedWeaponHoldLeft(ball, kind) ?? 0,
      weaponDisplayScale: (kind) =>
          state.powerUps?.weaponDisplayScale(kind) ?? 1,
      skillRange: (kind) => state.powerUps?.skillRange(kind) ?? 1,
    );
    if (look != BallLook.pictures || handsOnPictures) {
      paintHands(canvas, ball);
    }
    if (ball.isGhost) canvas.restore();
  }

  // Laid-out "+N LINES" labels, reused across frames. Opacity is rounded to
  // 1/16 steps so a fading label is laid out a handful of times, not per frame.
  static final Map<String, TextPainter> _textCache = {};

  void _paintFloatingText(Canvas canvas) {
    for (final text in state.floatingTexts.items) {
      final alpha = (text.opacity.clamp(0.0, 1.0) * 16).round() / 16;
      final key =
          '${text.text}|${text.color.toARGB32()}|$alpha|${text.callout}|${text.calloutStyle.name}|${text.calloutBubble.name}';
      final calloutInk = switch (text.calloutStyle) {
        CalloutStyle.normal => const Color(0xFF111111),
        CalloutStyle.rare => const Color(0xFF0D47A1),
        CalloutStyle.epic => const Color(0xFF6A1B9A),
        CalloutStyle.special => const Color(0xFF8B0000),
      };
      final painter = _textCache[key] ??= TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: (text.callout ? calloutInk : text.color).withValues(
              alpha: alpha,
            ),
            fontSize: text.calloutStyle == CalloutStyle.special ? 19 : 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (_textCache.length > 200) _textCache.remove(_textCache.keys.first);
      final origin =
          text.position - Offset(painter.width / 2, painter.height / 2);
      if (text.callout) {
        final bubbleColor = switch (text.calloutStyle) {
          CalloutStyle.normal => Colors.white,
          CalloutStyle.rare => const Color(0xFFDDF3FF),
          CalloutStyle.epic => const Color(0xFFF1DEFF),
          CalloutStyle.special => const Color(0xFFFFE082),
        };
        final bubbleRect = Rect.fromLTWH(
          origin.dx - 8,
          origin.dy - 5,
          painter.width + 16,
          painter.height + 10,
        );
        final fill = Paint()
          ..color = bubbleColor.withValues(alpha: 0.96 * alpha);
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = text.calloutStyle == CalloutStyle.special ? 4 : 2.5
          ..color = calloutInk.withValues(alpha: alpha);
        switch (text.calloutBubble) {
          case CalloutBubble.shout:
            final bubble = _shoutBubble(bubbleRect);
            canvas
              ..drawPath(bubble, fill)
              ..drawPath(bubble, stroke);
          case CalloutBubble.speech:
            final bubble = RRect.fromRectAndRadius(
              bubbleRect,
              Radius.circular(text.calloutStyle == CalloutStyle.epic ? 3 : 8),
            );
            canvas
              ..drawRRect(bubble, fill)
              ..drawRRect(bubble, stroke);
            final tail = Path()
              ..moveTo(text.position.dx - 7, bubble.bottom - 1)
              ..lineTo(text.position.dx + 5, bubble.bottom - 1)
              ..lineTo(text.position.dx - 2, bubble.bottom + 9)
              ..close();
            canvas
              ..drawPath(tail, fill)
              ..drawPath(tail, stroke);
          case CalloutBubble.thought:
            canvas
              ..drawOval(bubbleRect, fill)
              ..drawOval(bubbleRect, stroke)
              ..drawCircle(
                Offset(bubbleRect.center.dx - 3, bubbleRect.bottom + 5),
                3.5,
                fill,
              )
              ..drawCircle(
                Offset(bubbleRect.center.dx - 7, bubbleRect.bottom + 11),
                2,
                fill,
              );
          case CalloutBubble.radio:
            final bubble = _radioBubble(bubbleRect);
            canvas
              ..drawPath(bubble, fill)
              ..drawPath(bubble, stroke);
        }
      }
      painter.paint(canvas, origin);
    }
  }

  Path _shoutBubble(Rect rect) {
    final center = rect.center;
    final path = Path();
    const points = 24;
    for (var i = 0; i < points; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / points;
      final spike = i.isEven ? 1.16 : 1.0;
      final point =
          center +
          Offset(
            math.cos(angle) * rect.width / 2 * spike,
            math.sin(angle) * rect.height / 2 * spike,
          );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  Path _radioBubble(Rect rect) {
    const cut = 6.0;
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right, rect.bottom - cut)
      ..lineTo(rect.right - cut, rect.bottom)
      ..lineTo(rect.left + cut, rect.bottom)
      ..lineTo(rect.left, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
