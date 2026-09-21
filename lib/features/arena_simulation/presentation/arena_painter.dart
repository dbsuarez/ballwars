import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/math_utils.dart';
import '../domain/simulation_state.dart';

class ArenaPainter extends CustomPainter {
  final SimulationState state;
  final double arenaRadius;
  final double rimAngle;

  static const double _ballGlowPadding = 4.0;

  ArenaPainter({
    required this.state,
    required this.arenaRadius,
    required this.rimAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.shortestSide / (2 * arenaRadius);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale, scale);

    _paintBackground(canvas);
    _paintRim(canvas);
    _paintLaserRays(canvas);
    _paintParticles(canvas);
    _paintBallTokens(canvas);
    _paintFloatingText(canvas);

    canvas.restore();
  }

  void _paintBackground(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset.zero,
        arenaRadius,
        [AppColors.arenaDiscStart, AppColors.arenaDiscEnd],
      );
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  void _paintRim(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = AppColors.rimGlow
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);
    canvas.drawCircle(Offset.zero, arenaRadius, paint);
  }

  void _paintLaserRays(Canvas canvas) {
    final owners = state.territory.sectorOwners;
    final wedges = _computeWedges();

    for (var i = 0; i < owners.length; i++) {
      final ownerId = owners[i];
      if (ownerId.isEmpty) continue;
      final ownerBall = state.balls.where((b) => b.config.id == ownerId);
      if (ownerBall.isEmpty) continue;
      final ball = ownerBall.first;

      final theta = rimAngle + (i * (2 * math.pi / 360));
      final rimPoint = Offset(math.cos(theta), math.sin(theta)) * arenaRadius;

      final paint = Paint()
        ..color = ball.config.primaryColor.withOpacity(0.85)
        ..strokeWidth = 1.2;

      for (final segment in _visibleRaySegments(ball.position, rimPoint, ownerId, wedges)) {
        canvas.drawLine(segment[0], segment[1], paint);
      }
    }
  }

  /// Computes each ball's current owned territory as a wedge (apex at the
  /// ball's position, bounded by the rim points of its first/last owned
  /// sector), used to cut other balls' rays wherever they pass through it —
  /// not just where a ball's body physically sits on the line.
  Map<String, _Wedge> _computeWedges() {
    final owners = state.territory.sectorOwners;
    final total = owners.length;
    final sectorAngleStep = 2 * math.pi / total;
    final wedges = <String, _Wedge>{};

    Offset rimPointAt(int index) {
      final theta = rimAngle + (index * sectorAngleStep);
      return Offset(math.cos(theta), math.sin(theta)) * arenaRadius;
    }

    for (var i = 0; i < total; i++) {
      final id = owners[i];
      if (id.isEmpty) continue;
      final prev = (i - 1 + total) % total;
      if (owners[prev] == id) continue; // not the start of this ball's run

      var end = i;
      while (owners[(end + 1) % total] == id) {
        end = (end + 1) % total;
      }

      final ownerBall = state.balls.where((b) => b.config.id == id);
      if (ownerBall.isEmpty) continue;

      wedges[id] = _Wedge(
        apex: ownerBall.first.position,
        edge1: rimPointAt(i),
        edge2: rimPointAt(end),
        minAngle: rimAngle + i * sectorAngleStep,
        maxAngle: rimAngle + end * sectorAngleStep,
      );
    }

    return wedges;
  }

  /// Splits a ray into the sub-segments that are NOT covered by any other
  /// ball's body or territory wedge, so the ray visibly cuts wherever an
  /// opposing ball or its owned fan crosses it, while staying visible
  /// before and after that crossing.
  List<List<Offset>> _visibleRaySegments(
    Offset origin,
    Offset target,
    String ownerId,
    Map<String, _Wedge> wedges,
  ) {
    final blocked = <List<double>>[];
    for (final ball in state.balls) {
      if (ball.config.id == ownerId) continue;
      final range = MathUtils.segmentCircleOverlapRange(origin, target, ball.position, ball.radius);
      if (range != null) blocked.add(range);
    }

    for (final entry in wedges.entries) {
      if (entry.key == ownerId) continue;
      blocked.addAll(_blockedRangesForWedge(origin, target, entry.value));
    }

    if (blocked.isEmpty) return [[origin, target]];

    blocked.sort((a, b) => a[0].compareTo(b[0]));
    final merged = <List<double>>[];
    for (final range in blocked) {
      if (merged.isNotEmpty && range[0] <= merged.last[1]) {
        merged.last[1] = math.max(merged.last[1], range[1]);
      } else {
        merged.add([range[0], range[1]]);
      }
    }

    final segments = <List<Offset>>[];
    final delta = target - origin;
    var cursor = 0.0;
    for (final range in merged) {
      if (range[0] > cursor) {
        segments.add([origin + delta * cursor, origin + delta * range[0]]);
      }
      cursor = range[1];
    }
    if (cursor < 1.0) {
      segments.add([origin + delta * cursor, origin + delta * 1.0]);
    }
    return segments;
  }

  /// Finds the t-ranges along segment [origin]->[target] that fall inside
  /// [wedge]'s angular span as seen from its apex, by crossing the ray
  /// against the wedge's two boundary edges and sampling each resulting
  /// sub-interval's midpoint (robust to any number/order of crossings).
  List<List<double>> _blockedRangesForWedge(Offset origin, Offset target, _Wedge wedge) {
    final tValues = <double>[0.0, 1.0];
    final t1 = MathUtils.segmentSegmentIntersectionT(origin, target, wedge.apex, wedge.edge1);
    if (t1 != null) tValues.add(t1);
    final t2 = MathUtils.segmentSegmentIntersectionT(origin, target, wedge.apex, wedge.edge2);
    if (t2 != null) tValues.add(t2);
    tValues.sort();

    final delta = target - origin;
    final blocked = <List<double>>[];
    for (var i = 0; i < tValues.length - 1; i++) {
      final segStart = tValues[i];
      final segEnd = tValues[i + 1];
      if (segEnd - segStart < 1e-9) continue;

      final mid = (segStart + segEnd) / 2;
      final midPoint = origin + delta * mid;
      final angle = math.atan2(midPoint.dy - wedge.apex.dy, midPoint.dx - wedge.apex.dx);
      if (MathUtils.isAngleInRange(angle, wedge.minAngle, wedge.maxAngle)) {
        blocked.add([segStart, segEnd]);
      }
    }
    return blocked;
  }

  void _paintParticles(Canvas canvas) {
    for (final particle in state.particles.particles) {
      final lifeRatio = 1.0 - (particle.age / particle.lifespan).clamp(0.0, 1.0);
      // Young particles flash white-hot and cool into their collision color
      // as they age, for a punchier spark burst.
      final hotness = (lifeRatio * 1.6).clamp(0.0, 1.0);
      final sparkColor = Color.lerp(particle.color, Colors.white, hotness)!;
      final paint = Paint()
        ..color = sparkColor.withOpacity(lifeRatio)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(particle.position, particle.baseRadius * lifeRatio, paint);
    }
  }

  void _paintBallTokens(Canvas canvas) {
    for (final ball in state.balls) {
      final glowPaint = Paint()
        ..color = ball.config.glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);
      canvas.drawCircle(ball.position, ball.radius + _ballGlowPadding, glowPaint);

      final fillPaint = Paint()..color = ball.config.primaryColor;
      canvas.drawCircle(ball.position, ball.radius, fillPaint);

      final image = ball.cachedUiImage;
      if (image != null) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: ball.position, radius: ball.radius)));
        final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
        final dstRect = Rect.fromCircle(center: ball.position, radius: ball.radius);
        canvas.drawImageRect(image, srcRect, dstRect, Paint());
        canvas.restore();
      } else {
        final textPainter = TextPainter(
          text: TextSpan(
            text: ball.config.name.isNotEmpty ? ball.config.name.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: ball.radius, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          ball.position - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      }

      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white;
      canvas.drawCircle(ball.position, ball.radius, borderPaint);
    }
  }

  void _paintFloatingText(Canvas canvas) {
    for (final text in state.floatingTexts.items) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text.text,
          style: TextStyle(
            color: text.color.withOpacity(text.opacity),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, text.position);
    }
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}

/// A ball's currently owned territory, as an angular wedge fanning out from
/// its current position to the rim points of its first/last owned sector.
class _Wedge {
  final Offset apex;
  final Offset edge1;
  final Offset edge2;
  final double minAngle;
  final double maxAngle;

  const _Wedge({
    required this.apex,
    required this.edge1,
    required this.edge2,
    required this.minAngle,
    required this.maxAngle,
  });
}
