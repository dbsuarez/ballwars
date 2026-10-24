import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';

/// A short winner cutscene for the Hook's "COME OVER HERE!" finishing move.
class HarpoonCinematic extends StatefulWidget {
  const HarpoonCinematic({
    super.key,
    required this.winner,
    required this.loser,
    required this.onFinished,
  });

  final CustomBall winner;
  final CustomBall loser;
  final VoidCallback onFinished;

  @override
  State<HarpoonCinematic> createState() => _HarpoonCinematicState();
}

class _HarpoonCinematicState extends State<HarpoonCinematic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward().whenComplete(widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = BallWarsColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [colors.surfaceHigh, colors.background, Colors.black],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => LayoutBuilder(
          builder: (context, bounds) {
            final size = math.min(110.0, bounds.maxWidth * 0.2);
            final y = bounds.maxHeight * 0.5 - size / 2;
            final winnerX = bounds.maxWidth * 0.14;
            final loserStart = bounds.maxWidth * 0.72;
            final pull = ((_controller.value - 0.2) / 0.45).clamp(0.0, 1.0);
            final uppercut = ((_controller.value - 0.7) / 0.3).clamp(0.0, 1.0);
            final loserX =
                loserStart + (winnerX + size * 1.5 - loserStart) * pull;
            final loserY = y - math.sin(uppercut * math.pi / 2) * size * 1.25;
            final winnerCenter = Offset(winnerX + size / 2, y + size / 2);
            final loserCenter = Offset(loserX + size / 2, loserY + size / 2);
            return Stack(
              children: [
                if (uppercut > 0.15)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Color.lerp(
                        Colors.transparent,
                        const Color(0xFFFFF3D0),
                        (math.sin(uppercut * math.pi) * 0.75).clamp(0, 1),
                      )!,
                    ),
                  ),
                CustomPaint(
                  size: bounds.biggest,
                  painter: _HarpoonLinePainter(
                    from: winnerCenter,
                    to: loserCenter,
                    visible: _controller.value >= 0.18 && uppercut < 0.9,
                  ),
                ),
                Positioned(
                  left: winnerX,
                  top: y,
                  child: CircularBallPreview(ball: widget.winner, size: size),
                ),
                Positioned(
                  left: loserX,
                  top: loserY,
                  child: Transform.rotate(
                    angle: uppercut * 0.7,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircularBallPreview(ball: widget.loser, size: size),
                        Positioned(
                          left: size * 0.2,
                          top: -size * 0.34,
                          child: Text(
                            '★  ×  ★',
                            style: TextStyle(
                              color: const Color(0xFFFFD54F),
                              fontSize: size * 0.25,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.9),
                  child: Text(
                    'FINISHING MOVE',
                    style: AppText.ui(
                      13,
                      FontWeight.w800,
                      color: const Color(0xFFFF5B4D),
                      letterSpacing: 4,
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.72),
                  child: Text(
                    uppercut > 0 ? 'UPPERCUT!' : 'COME OVER HERE!',
                    key: const ValueKey('harpoon-cinematic-yell'),
                    style: AppText.ui(
                      24,
                      FontWeight.w900,
                      color: uppercut > 0
                          ? const Color(0xFFFFD54F)
                          : colors.text,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HarpoonLinePainter extends CustomPainter {
  const _HarpoonLinePainter({
    required this.from,
    required this.to,
    required this.visible,
  });

  final Offset from;
  final Offset to;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final paint = Paint()
      ..color = const Color(0xFFB8C2CC)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
    final direction = (to - from) / math.max(1, (to - from).distance);
    final side = Offset(-direction.dy, direction.dx);
    canvas.drawLine(to, to - direction * 20 + side * 12, paint);
    canvas.drawLine(to, to - direction * 20 - side * 12, paint);
  }

  @override
  bool shouldRepaint(_HarpoonLinePainter old) =>
      old.from != from || old.to != to || old.visible != visible;
}
