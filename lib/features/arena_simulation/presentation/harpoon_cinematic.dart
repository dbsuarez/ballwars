import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';

/// A comic-book finishing cutscene for the Hook's "COME OVER HERE!" move.
class HarpoonCinematic extends StatefulWidget {
  const HarpoonCinematic({
    super.key,
    required this.winner,
    required this.loser,
    required this.onFinished,
    this.onHookFired,
    this.onImpact,
  });

  final CustomBall winner;
  final CustomBall loser;
  final VoidCallback onFinished;
  final VoidCallback? onHookFired;
  final VoidCallback? onImpact;

  @override
  State<HarpoonCinematic> createState() => _HarpoonCinematicState();
}

class _HarpoonCinematicState extends State<HarpoonCinematic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hookSoundPlayed = false;
  bool _impactSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    )..addListener(_playTimedSounds);
    _controller.forward().whenComplete(widget.onFinished);
  }

  void _playTimedSounds() {
    if (!_hookSoundPlayed && _controller.value >= 0.18) {
      _hookSoundPlayed = true;
      widget.onHookFired?.call();
    }
    if (!_impactSoundPlayed && _controller.value >= 0.76) {
      _impactSoundPlayed = true;
      widget.onImpact?.call();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_playTimedSounds)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BallWarsColors.of(context);
    return Semantics(
      label: 'Hook finishing move cinematic',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [colors.surfaceHigh, const Color(0xFF190D13), Colors.black],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, bounds) {
              final t = _controller.value;
              final diameter = math.min(138.0, bounds.maxWidth * 0.25);
              final radius = diameter / 2;
              final centerY = bounds.maxHeight * 0.58;
              final winnerX = bounds.maxWidth * 0.18;
              final loserStartX = bounds.maxWidth * 0.78;
              final hook = _range(t, 0.14, 0.25);
              final pull = Curves.easeInCubic.transform(_range(t, 0.32, 0.62));
              final windUp = Curves.easeInOut.transform(_range(t, 0.62, 0.73));
              final uppercut = Curves.easeOutQuart.transform(
                _range(t, 0.73, 0.9),
              );
              final loserX =
                  loserStartX +
                  (winnerX + diameter * 1.28 - loserStartX) * pull;
              final loserY = centerY - uppercut * diameter * 1.65;
              final winnerY = centerY + windUp * diameter * 0.12;
              final winnerCenter = Offset(winnerX, winnerY);
              final loserCenter = Offset(loserX, loserY);
              final impact = _range(t, 0.73, 0.82);
              final shake = impact < 1
                  ? math.sin(impact * math.pi * 8) * (1 - impact) * 10
                  : 0.0;

              return Transform.translate(
                offset: Offset(shake, 0),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        key: const ValueKey('harpoon-cinematic-effects'),
                        painter: _FinisherPainter(
                          winner: widget.winner,
                          loser: widget.loser,
                          winnerCenter: winnerCenter,
                          loserCenter: loserCenter,
                          radius: radius,
                          hookProgress: hook,
                          pullProgress: pull,
                          uppercutProgress: uppercut,
                          impactProgress: impact,
                        ),
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0, -0.91),
                      child: Text(
                        'FINISHING MOVE',
                        style: AppText.ui(
                          14,
                          FontWeight.w900,
                          color: const Color(0xFFFF4B3E),
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      top: bounds.maxHeight * 0.16,
                      child: Center(
                        child: _YellBubble(
                          key: const ValueKey('harpoon-cinematic-yell'),
                          text: t >= 0.7 ? 'UPPERCUT!' : 'COME OVER HERE!',
                          impact: t >= 0.7,
                        ),
                      ),
                    ),
                    _name(
                      widget.winner.name,
                      winnerX,
                      winnerY,
                      diameter,
                      bounds,
                    ),
                    _name(widget.loser.name, loserX, loserY, diameter, bounds),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Positioned _name(
    String name,
    double x,
    double y,
    double width,
    BoxConstraints bounds,
  ) => Positioned(
    left: (x - width / 2).clamp(4, bounds.maxWidth - width - 4),
    width: width,
    top: math.min(bounds.maxHeight - 30, y + width * 0.62),
    child: Text(
      name,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.ui(12, FontWeight.w800, color: Colors.white),
    ),
  );

  double _range(double value, double start, double end) =>
      ((value - start) / (end - start)).clamp(0.0, 1.0);
}

class _YellBubble extends StatelessWidget {
  const _YellBubble({super.key, required this.text, required this.impact});

  final String text;
  final bool impact;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: impact ? -0.04 : 0.025,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: impact ? const Color(0xFFFFD43B) : Colors.white,
        border: Border.all(color: Colors.black, width: 4),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0xFFFF4B3E), offset: Offset(6, 6)),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AppText.ui(
          25,
          FontWeight.w900,
          color: Colors.black,
          letterSpacing: 1,
        ),
      ),
    ),
  );
}

class _FinisherPainter extends CustomPainter {
  const _FinisherPainter({
    required this.winner,
    required this.loser,
    required this.winnerCenter,
    required this.loserCenter,
    required this.radius,
    required this.hookProgress,
    required this.pullProgress,
    required this.uppercutProgress,
    required this.impactProgress,
  });

  final CustomBall winner;
  final CustomBall loser;
  final Offset winnerCenter;
  final Offset loserCenter;
  final double radius;
  final double hookProgress;
  final double pullProgress;
  final double uppercutProgress;
  final double impactProgress;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSpeedLines(canvas);
    if (impactProgress > 0 && impactProgress < 1) {
      _paintImpact(canvas, loserCenter, impactProgress);
    }
    final lineStart = winnerCenter + Offset(radius * 0.65, -radius * 0.05);
    final lineEnd = Offset.lerp(lineStart, loserCenter, hookProgress)!;
    if (hookProgress > 0 && uppercutProgress < 0.72) {
      _paintChainAndHook(canvas, lineStart, lineEnd);
    }
    _paintSmiley(
      canvas,
      loserCenter,
      loser.primaryColor,
      dizzy: true,
      rotation: uppercutProgress * 0.55,
    );
    _paintWinner(canvas);
  }

  void _paintSpeedLines(Canvas canvas) {
    if (pullProgress <= 0 || pullProgress >= 1) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.28 * (1 - pullProgress))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = loserCenter.dy - radius + i * radius * 0.25;
      final length = radius * (0.7 + (i % 3) * 0.35);
      canvas.drawLine(
        Offset(loserCenter.dx + radius, y),
        Offset(loserCenter.dx + radius + length, y),
        paint,
      );
    }
  }

  void _paintWinner(Canvas canvas) {
    final glove = winnerCenter + Offset(radius * 0.88, radius * 0.18);
    final raisedGlove = glove - Offset(0, uppercutProgress * radius * 1.22);
    _paintSmiley(canvas, winnerCenter, winner.primaryColor);
    final arm = Paint()
      ..color = const Color(0xFF111114)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      winnerCenter + Offset(radius * 0.58, radius * 0.32),
      raisedGlove,
      arm,
    );
    _paintGlove(canvas, raisedGlove, radius * 0.25, fist: true);
    _paintGlove(
      canvas,
      winnerCenter + Offset(-radius * 0.9, radius * 0.32),
      radius * 0.22,
    );
  }

  void _paintSmiley(
    Canvas canvas,
    Offset center,
    Color color, {
    bool dizzy = false,
    double rotation = 0,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final ink = Paint()
      ..color = const Color(0xFF111114)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
    canvas.drawCircle(Offset.zero, radius, ink);
    for (final x in [-radius * 0.34, radius * 0.34]) {
      final eye = Offset(x, -radius * 0.2);
      if (dizzy) {
        canvas.drawLine(
          eye - Offset(radius * 0.11, radius * 0.11),
          eye + Offset(radius * 0.11, radius * 0.11),
          ink,
        );
        canvas.drawLine(
          eye + Offset(-radius * 0.11, radius * 0.11),
          eye + Offset(radius * 0.11, -radius * 0.11),
          ink,
        );
      } else {
        canvas.drawCircle(eye, radius * 0.18, Paint()..color = Colors.white);
        canvas.drawCircle(eye, radius * 0.18, ink);
        canvas.drawCircle(
          eye + Offset(radius * 0.04, 0),
          radius * 0.075,
          Paint()..color = Colors.black,
        );
      }
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, dizzy ? radius * 0.5 : radius * 0.22),
        width: radius,
        height: dizzy ? radius * 0.5 : radius * 0.7,
      ),
      dizzy ? math.pi + 0.2 : 0.25,
      dizzy ? math.pi - 0.4 : math.pi - 0.5,
      false,
      ink,
    );
    canvas.restore();
    if (dizzy) {
      _paintGlove(
        canvas,
        center + Offset(-radius * 0.92, radius * 0.3),
        radius * 0.2,
      );
      _paintGlove(
        canvas,
        center + Offset(radius * 0.92, radius * 0.3),
        radius * 0.2,
      );
      final stars = TextPainter(
        text: TextSpan(
          text: '★  ×  ★',
          style: TextStyle(
            color: const Color(0xFFFFD43B),
            fontSize: radius * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      stars.paint(canvas, center - Offset(stars.width / 2, radius * 1.5));
    }
  }

  void _paintGlove(
    Canvas canvas,
    Offset center,
    double r, {
    bool fist = false,
  }) {
    final outline = Paint()
      ..color = const Color(0xFF111114)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, r * 0.28);
    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r, outline);
    if (fist) {
      canvas.drawLine(
        center + Offset(-r * 0.55, 0),
        center + Offset(r * 0.55, 0),
        outline..strokeWidth = math.max(1.5, r * 0.14),
      );
    }
  }

  void _paintChainAndHook(Canvas canvas, Offset from, Offset to) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 9,
    );
    final chain = Paint()
      ..color = const Color(0xFFDCE5EC)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, chain);
    final delta = to - from;
    final direction = delta / math.max(1, delta.distance);
    final side = Offset(-direction.dy, direction.dx);
    final hook = Path()
      ..moveTo(to.dx, to.dy)
      ..quadraticBezierTo(
        to.dx - direction.dx * radius * 0.45 + side.dx * radius * 0.35,
        to.dy - direction.dy * radius * 0.45 + side.dy * radius * 0.35,
        to.dx - direction.dx * radius * 0.12 - side.dx * radius * 0.18,
        to.dy - direction.dy * radius * 0.12 - side.dy * radius * 0.18,
      );
    canvas.drawPath(
      hook,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(hook, chain..strokeWidth = 6);
  }

  void _paintImpact(Canvas canvas, Offset center, double progress) {
    final alpha = (1 - progress).clamp(0.0, 1.0);
    final rays = Paint()
      ..color = const Color(0xFFFFD43B).withValues(alpha: alpha)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 16; i++) {
      final a = math.pi * 2 * i / 16;
      final unit = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + unit * radius * (0.8 + progress),
        center + unit * radius * (1.5 + progress * 1.4),
        rays,
      );
    }
    canvas.drawCircle(
      center,
      radius * (0.5 + progress * 1.4),
      Paint()..color = Colors.white.withValues(alpha: alpha * 0.7),
    );
  }

  @override
  bool shouldRepaint(_FinisherPainter old) =>
      old.winnerCenter != winnerCenter ||
      old.loserCenter != loserCenter ||
      old.hookProgress != hookProgress ||
      old.pullProgress != pullProgress ||
      old.uppercutProgress != uppercutProgress ||
      old.impactProgress != impactProgress;
}
