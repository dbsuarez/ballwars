import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/hair_styles.dart';
import '../domain/simulation_ball.dart';

/// Lightweight deterministic hairstyles ([HairStyles.count] of them). All
/// are drawn from paths and primitives (no blur), so they work identically
/// in the arena and video, on pictures and faces alike.
class BallHairPainter {
  const BallHairPainter._();

  /// Styles male balls draw from (short cuts).
  static const List<int> maleStyles = HairStyles.male;

  /// Styles female balls draw from (long hair, ponytails, pigtails, bobs,
  /// buns).
  static const List<int> femaleStyles = HairStyles.female;

  static void paint(Canvas canvas, SimulationBall ball) {
    final style = ball.hairstyle;
    final color = ball.hairColor;
    if (style == null || color == null) return;
    final c = ball.position;
    final r = ball.radius;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dark = Paint()
      ..color = Color.lerp(color, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.07)
      ..strokeCap = StrokeCap.round;
    final variant = style % 5;
    final family = style ~/ 5;

    if (family == 0) {
      // Spikes: five silhouettes with different lean and height.
      final path = Path()..moveTo(c.dx - r * 0.82, c.dy - r * 0.45);
      for (var i = 0; i < 7; i++) {
        final x = c.dx - r * 0.75 + i * r * 0.25;
        final lean = (variant - 2) * r * 0.045;
        path
          ..lineTo(x + lean, c.dy - r * (1.02 + (i + variant) % 3 * 0.16))
          ..lineTo(x + r * 0.15, c.dy - r * 0.55);
      }
      path
        ..lineTo(c.dx + r * 0.82, c.dy - r * 0.28)
        ..quadraticBezierTo(
          c.dx,
          c.dy - r * 0.78,
          c.dx - r * 0.82,
          c.dy - r * 0.45,
        )
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, dark);
    } else if (family == 1) {
      // Rounded cuts: bowl, bob, afro, buns, and cloud curls.
      final bumps = 4 + variant;
      for (var i = 0; i < bumps; i++) {
        final t = bumps == 1 ? 0.5 : i / (bumps - 1);
        final x = c.dx + (t * 1.45 - 0.725) * r;
        final y = c.dy - r * (0.72 + math.sin(t * math.pi) * 0.3);
        canvas.drawCircle(
          x == c.dx ? Offset(x, y) : Offset(x, y),
          r * (0.28 + variant * 0.025),
          paint,
        );
      }
      if (variant == 3) {
        canvas.drawCircle(c + Offset(-r * 0.82, -r * 0.78), r * 0.3, paint);
        canvas.drawCircle(c + Offset(r * 0.82, -r * 0.78), r * 0.3, paint);
      }
    } else if (family == 2) {
      // Swept and mohawk cuts.
      final path = Path()
        ..moveTo(c.dx - r * 0.82, c.dy - r * 0.42)
        ..quadraticBezierTo(
          c.dx - r * (0.2 + variant * 0.08),
          c.dy - r * (1.25 + variant * 0.07),
          c.dx + r * 0.88,
          c.dy - r * (0.62 - variant * 0.03),
        )
        ..quadraticBezierTo(
          c.dx + r * 0.3,
          c.dy - r * 0.62,
          c.dx - r * 0.82,
          c.dy - r * 0.42,
        )
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(path, dark);
      if (variant >= 3) {
        canvas.drawRect(
          Rect.fromCenter(
            center: c - Offset(0, r * 1.02),
            width: r * 0.25,
            height: r * 0.75,
          ),
          paint,
        );
      }
    } else if (family >= 4) {
      _paintLong(canvas, c, r, family, variant, paint, dark);
    } else {
      // Long cuts and ponytails.
      final cap = Rect.fromCenter(
        center: c - Offset(0, r * 0.55),
        width: r * 1.65,
        height: r * (0.75 + variant * 0.05),
      );
      canvas.drawArc(cap, math.pi, math.pi, true, paint);
      final side = variant.isEven ? 1.0 : -1.0;
      final pony = Path()
        ..moveTo(c.dx + side * r * 0.72, c.dy - r * 0.63)
        ..quadraticBezierTo(
          c.dx + side * r * 1.35,
          c.dy - r * 0.15,
          c.dx + side * r * 1.05,
          c.dy + r * (0.45 + variant * 0.08),
        )
        ..quadraticBezierTo(
          c.dx + side * r * 0.72,
          c.dy + r * 0.05,
          c.dx + side * r * 0.72,
          c.dy - r * 0.63,
        )
        ..close();
      canvas.drawPath(pony, paint);
      if (variant == 4) {
        canvas.drawCircle(c - Offset(0, r * 1.12), r * 0.32, paint);
      }
    }
  }

  /// The female families (styles 20 and up): long straight, ponytail, two
  /// pigtails, bob and top bun, five variants each. Coordinates are in ball
  /// radii from the center; the face (eyes at x +-0.12..0.56, y -0.4..0.04)
  /// stays clear: side hair keeps to |x| > 0.6 down there.
  /// The two sides (left, right) the long styles mirror over.
  static const List<double> _sides = [-1.0, 1.0];

  /// Fill for the ties; [_paintLong] sets its color each call, so it is never
  /// allocated while painting.
  static final Paint _ink = Paint();

  static void _paintLong(
    Canvas canvas,
    Offset c,
    double r,
    int family,
    int variant,
    Paint paint,
    Paint dark,
  ) {
    Offset u(double x, double y) => Offset(c.dx + x * r, c.dy + y * r);
    final ink = _ink..color = dark.color;
    void fill(Path path) {
      canvas.drawPath(path, paint);
      canvas.drawPath(path, dark);
    }

    void ball(double x, double y, double radius) {
      canvas.drawCircle(u(x, y), radius * r, paint);
      canvas.drawCircle(u(x, y), radius * r, dark);
    }

    // A tapered lock of hair from [start] (width [w]) to a point at [end].
    Path lock(Offset start, Offset c1, Offset c2, Offset end, double w) {
      final d = end - start;
      final n = Offset(-d.dy, d.dx) / d.distance;
      Offset at(Offset o, double k) => u(o.dx + n.dx * k, o.dy + n.dy * k);
      return Path()
        ..moveTo(at(start, w).dx, at(start, w).dy)
        ..cubicTo(
          at(c1, w).dx,
          at(c1, w).dy,
          at(c2, w * 0.5).dx,
          at(c2, w * 0.5).dy,
          u(end.dx, end.dy).dx,
          u(end.dx, end.dy).dy,
        )
        ..cubicTo(
          at(c2, -w * 0.5).dx,
          at(c2, -w * 0.5).dy,
          at(c1, -w).dx,
          at(c1, -w).dy,
          at(start, -w).dx,
          at(start, -w).dy,
        )
        ..close();
    }

    // A braid: beads shrinking from [from] to [to], swaying outwards.
    void braid(Offset from, Offset to, double side) {
      for (var k = 0; k <= 5; k++) {
        final t = k / 5;
        final p = Offset.lerp(from, to, t)!;
        ball(
          p.dx + math.sin(t * math.pi) * 0.1 * side,
          p.dy,
          0.15 * (1 - t * 0.4),
        );
      }
    }

    void tie(double x, double y) => canvas.drawCircle(u(x, y), r * 0.1, ink);

    // Hair over the head down to [lenL] / [lenR] (in radii below the
    // center), with a fringe: [fringe] is how low it reaches in the middle,
    // [part] leans it to one side, [parted] opens it in the middle. [flare]
    // widens long hair at the bottom.
    Path frame({
      double lenL = -0.2,
      double? lenR,
      double fringe = -0.56,
      double part = 0,
      bool parted = false,
      double flare = 0,
    }) {
      final right = lenR ?? lenL;
      Path p = Path();
      final oL = lenL < 0.1 ? 1.0 : 1.02 + flare;
      final oR = right < 0.1 ? 1.0 : 1.02 + flare;
      final iL = oL - (lenL < 0.1 ? 0.14 : 0.24);
      final iR = oR - (right < 0.1 ? 0.14 : 0.24);
      p.moveTo(u(-oL, lenL).dx, u(-oL, lenL).dy);
      final l1 = u(-(1.06 + flare), lenL - (lenL + 0.75) * 0.45);
      final l2 = u(-1.08, -0.85);
      final top = u(-0.62, -1.08);
      p.cubicTo(l1.dx, l1.dy, l2.dx, l2.dy, top.dx, top.dy);
      final crown = u(0, -1.28);
      final topR = u(0.62, -1.08);
      p.quadraticBezierTo(crown.dx, crown.dy, topR.dx, topR.dy);
      final r2 = u(1.08, -0.85);
      final r1 = u(1.06 + flare, right - (right + 0.75) * 0.45);
      final bottomR = u(oR, right);
      p.cubicTo(r2.dx, r2.dy, r1.dx, r1.dy, bottomR.dx, bottomR.dy);
      final innerR = u(iR, right - 0.03);
      p.lineTo(innerR.dx, innerR.dy);
      final ir1 = u(iR + 0.04, right - (right + 0.62) * 0.5);
      final ir2 = u(0.88, -0.5);
      final templeR = u(0.58, -0.62);
      p.cubicTo(ir1.dx, ir1.dy, ir2.dx, ir2.dy, templeR.dx, templeR.dy);
      final templeL = u(-0.58, -0.62);
      if (parted) {
        final a = u(0.25, -0.64);
        final mid = u(part, -0.98);
        final b = u(-0.25, -0.64);
        p
          ..quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy)
          ..quadraticBezierTo(b.dx, b.dy, templeL.dx, templeL.dy);
      } else {
        final f = u(part, 2 * fringe + 0.62);
        p.quadraticBezierTo(f.dx, f.dy, templeL.dx, templeL.dy);
      }
      final il2 = u(-0.88, -0.5);
      final il1 = u(-(iL + 0.04), lenL - (lenL + 0.62) * 0.5);
      final innerL = u(-iL, lenL - 0.03);
      p
        ..cubicTo(il2.dx, il2.dy, il1.dx, il1.dy, innerL.dx, innerL.dy)
        ..close();
      return p;
    }

    switch (family) {
      case 4: // Long straight.
        switch (variant) {
          case 0:
            fill(frame(lenL: 0.7, fringe: -0.52));
          case 1:
            fill(frame(lenL: 0.8, fringe: -0.6, part: 0.4));
          case 2:
            fill(frame(lenL: 0.75, parted: true));
          case 3:
            fill(frame(lenL: 0.9, fringe: -0.56, part: -0.35, flare: 0.08));
            for (final s in _sides) {
              ball(s * 1.0, 0.86, 0.13);
            }
          default:
            fill(frame(lenL: 1.05, fringe: -0.5, flare: 0.12));
        }
      case 5: // Ponytail.
        switch (variant) {
          case 0:
            fill(
              lock(
                const Offset(0.6, -0.92),
                const Offset(1.3, -1.25),
                const Offset(1.55, -0.4),
                const Offset(1.2, 0.45),
                0.16,
              ),
            );
            fill(frame(fringe: -0.58, part: -0.3));
            tie(0.62, -0.92);
          case 1:
            fill(
              lock(
                const Offset(-0.6, -0.92),
                const Offset(-1.3, -1.25),
                const Offset(-1.55, -0.4),
                const Offset(-1.2, 0.45),
                0.16,
              ),
            );
            fill(frame(fringe: -0.62, part: 0.35));
            tie(-0.62, -0.92);
          case 2:
            fill(
              lock(
                const Offset(0.9, -0.42),
                const Offset(1.3, -0.3),
                const Offset(1.35, 0.3),
                const Offset(1.15, 0.8),
                0.15,
              ),
            );
            fill(frame(parted: true));
            tie(0.95, -0.42);
          case 3:
            fill(
              lock(
                const Offset(0.05, -1.12),
                const Offset(0.6, -1.7),
                const Offset(1.45, -0.9),
                const Offset(1.3, 0.2),
                0.17,
              ),
            );
            fill(frame(fringe: -0.54));
            tie(0.05, -1.14);
          default:
            braid(const Offset(0.95, -0.35), const Offset(1.05, 0.85), 1);
            fill(frame(fringe: -0.58, part: -0.3));
            tie(0.95, -0.4);
        }
      case 6: // Two pigtails.
        for (final s in _sides) {
          switch (variant) {
            case 0:
              fill(
                lock(
                  Offset(s * 0.8, -0.78),
                  Offset(s * 1.3, -0.95),
                  Offset(s * 1.55, -0.4),
                  Offset(s * 1.42, 0.08),
                  0.16,
                ),
              );
            case 1:
              fill(
                lock(
                  Offset(s * 0.92, -0.28),
                  Offset(s * 1.25, -0.1),
                  Offset(s * 1.28, 0.5),
                  Offset(s * 1.1, 0.95),
                  0.15,
                ),
              );
            case 2:
              fill(
                lock(
                  Offset(s * 0.78, -0.82),
                  Offset(s * 1.4, -0.95),
                  Offset(s * 1.5, 0.1),
                  Offset(s * 1.28, 0.8),
                  0.16,
                ),
              );
            case 3:
              braid(Offset(s * 0.95, -0.32), Offset(s * 1.05, 0.85), s);
            default:
              ball(s * 1.18, -0.6, 0.2);
              ball(s * 1.34, -0.3, 0.19);
              ball(s * 1.22, -0.02, 0.17);
          }
        }
        fill(
          variant == 2
              ? frame(parted: true)
              : frame(fringe: variant.isOdd ? -0.52 : -0.6),
        );
        for (final s in _sides) {
          switch (variant) {
            case 1 || 3:
              tie(s * 0.95, -0.36);
            case 4:
              tie(s * 0.95, -0.66);
            default:
              tie(s * 0.82, -0.8);
          }
        }
      case 7: // Bob.
        switch (variant) {
          case 0:
            fill(frame(lenL: 0.25, fringe: -0.5));
          case 1:
            fill(frame(lenL: 0.35, fringe: -0.62, part: 0.45));
          case 2:
            fill(frame(lenL: 0.15, parted: true, flare: 0.05));
          case 3:
            fill(frame(lenL: 0.1, lenR: 0.45, fringe: -0.62, part: 0.5));
          default:
            fill(frame(lenL: 0.2, fringe: -0.52));
            for (final s in _sides) {
              ball(s * 0.92, 0.2, 0.15);
            }
        }
      default: // Top bun.
        switch (variant) {
          case 0:
            ball(0, -1.28, 0.3);
          case 1:
            ball(0, -1.32, 0.38);
          case 2:
            ball(-0.72, -1.16, 0.28);
            ball(0.72, -1.16, 0.28);
          case 3:
            ball(-0.12, -1.26, 0.22);
            ball(0.16, -1.3, 0.24);
            ball(0.02, -1.45, 0.2);
            for (final s in _sides) {
              fill(
                lock(
                  Offset(s * 0.86, -0.5),
                  Offset(s * 0.98, -0.25),
                  Offset(s * 0.95, 0.0),
                  Offset(s * 0.86, 0.2),
                  0.06,
                ),
              );
            }
          default:
            ball(0, -1.25, 0.3);
            for (final s in _sides) {
              fill(
                lock(
                  Offset(s * 0.84, -0.55),
                  Offset(s * 1.02, -0.2),
                  Offset(s * 1.0, 0.15),
                  Offset(s * 0.9, 0.4),
                  0.08,
                ),
              );
            }
        }
        fill(
          variant == 1
              ? frame(fringe: -0.62, part: 0.35)
              : variant == 2
              ? frame(parted: true)
              : frame(fringe: variant == 4 ? -0.5 : -0.58),
        );
        if (variant != 2) {
          canvas.drawArc(
            Rect.fromCircle(
              center: u(0, variant == 1 ? -1.32 : -1.27),
              radius: r * 0.16,
            ),
            math.pi * 0.9,
            math.pi * 1.2,
            false,
            dark,
          );
        }
    }
  }
}
