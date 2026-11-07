import '../../../core/sprites/sprite_registry.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/game_ui.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/ball_face_expression.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../ball_management/domain/custom_ball.dart';

/// User-owned illustration, approved for reuse on 2026-11-06.
/// Labels/buttons remain native widgets; original game painting is the fallback.
class LobbyHero extends StatelessWidget {
  const LobbyHero({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0, .09, .88, 1],
      ).createShader(bounds),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, .055, .945, 1],
        ).createShader(bounds),
        child: Image.asset(
          'assets/ui/lobby-hero.webp',
          fit: BoxFit.cover,
          cacheWidth:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 940),
          excludeFromSemantics: true,
          frameBuilder: (_, child, frame, _) => frame == null
              ? CustomPaint(painter: _HeroPainter(), size: Size.infinite)
              : child,
          errorBuilder: (_, _, _) =>
              CustomPaint(painter: _HeroPainter(), size: Size.infinite),
        ),
      ),
    ),
  );
}

class _HeroPainter extends CustomPainter {
  _HeroPainter() : super(repaint: SpriteRegistry.revision);
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 220;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(unit);
    final floor = Rect.fromCenter(
      center: const Offset(0, 40),
      width: 285,
      height: 100,
    );
    canvas.drawOval(
      floor,
      Paint()
        ..shader = RadialGradient(
          colors: [GameUi.blue.withValues(alpha: .3), Colors.transparent],
        ).createShader(floor),
    );
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        floor.inflate(i * 8.0),
        Paint()
          ..color = GameUi.cyan.withValues(alpha: .18 - i * .04)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
    final balls = <SimulationBall>[];
    for (final data in [
      (const Offset(-88, -25), GameUi.blue, PowerUpKind.pistol, 28.0),
      (const Offset(82, -38), GameUi.purple, PowerUpKind.bow, 27.0),
      (const Offset(-6, 12), const Color(0xFFFF5C64), PowerUpKind.sword, 43.0),
    ]) {
      final ball = SimulationBall(
        config: CustomBall(
          id: 'lobby-${balls.length}',
          name: '',
          primaryColor: data.$2,
          glowColor: data.$2,
        ),
        position: data.$1,
        velocity: Offset.fromDirection(-math.pi / 5, 100),
        radius: data.$4,
        lineCount: 0,
      )..life = 100;
      ball.equipWeapon(data.$3, dualWield: false);
      balls.add(ball);
    }
    for (final ball in balls) {
      canvas.drawCircle(
        ball.position,
        ball.radius * 1.4,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  ball.config.primaryColor.withValues(alpha: .3),
                  Colors.transparent,
                ],
              ).createShader(
                Rect.fromCircle(
                  center: ball.position,
                  radius: ball.radius * 1.4,
                ),
              ),
      );
      canvas.drawCircle(
        ball.position,
        ball.radius + 2,
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
      paintSmiley(
        canvas,
        ball,
        1,
        balls,
        expressionOverride: ball == balls.last
            ? FaceExpression.grinning
            : FaceExpression.angry,
      );
      PowerUpPainter.paintBallEffects(
        canvas,
        ball,
        weaponDisplayScale: (_, _) => .62,
      );
      paintHands(canvas, ball);
    }
    final slash = Path()
      ..moveTo(-30, 72)
      ..quadraticBezierTo(90, 90, 133, -7)
      ..quadraticBezierTo(110, 62, -30, 72);
    canvas.drawPath(
      slash,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.transparent, GameUi.gold, Color(0xFFFFF0B4)],
        ).createShader(const Rect.fromLTWH(-30, -7, 163, 97)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => false;
}
