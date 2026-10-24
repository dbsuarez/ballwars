import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/power_up.dart';
import '../../ball_management/domain/custom_ball.dart';
import 'finisher_profile.dart';
import 'arena_effect_library.dart';
import 'power_up_sprites.dart';

/// A comic-book finishing cutscene for the Hook's "COME OVER HERE!" move.
class HarpoonCinematic extends StatefulWidget {
  const HarpoonCinematic({
    super.key,
    required this.winner,
    required this.loser,
    required this.move,
    required this.onFinished,
    this.onHookFired,
    this.onImpact,
  });

  final CustomBall winner;
  final CustomBall loser;
  final String move;
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
    final profile = FinisherProfile.forMove(widget.move);
    return Semantics(
      label: 'Hook finishing move cinematic',
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Color.lerp(colors.surfaceHigh, profile.color, 0.18)!,
              Color.lerp(const Color(0xFF190D13), profile.color, 0.1)!,
              Colors.black,
            ],
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
              // Hook snaps out early so it can pull the opponent in. Other
              // items stay visible in flight until their impact beat.
              final hook = _range(
                t,
                0.14,
                profile.style == FinisherStyle.hook ? 0.25 : 0.72,
              );
              final pull = Curves.easeInCubic.transform(_range(t, 0.32, 0.62));
              final windUp = Curves.easeInOut.transform(_range(t, 0.62, 0.73));
              final uppercut = Curves.easeOutQuart.transform(
                _range(t, 0.73, 0.9),
              );
              final usesUppercut = profile.move == 'Hook';
              final closesDistance =
                  profile.move == 'Hook' ||
                  profile.style == FinisherStyle.melee;
              final loserX = closesDistance
                  ? loserStartX +
                        (winnerX + diameter * 1.28 - loserStartX) * pull
                  : loserStartX;
              final loserY =
                  centerY - (usesUppercut ? uppercut : 0) * diameter * 1.4;
              final winnerY = centerY + windUp * diameter * 0.12;
              final dash = profile.style == FinisherStyle.melee ? pull : 0.0;
              final winnerCenter = Offset(
                winnerX + (loserStartX - winnerX - diameter * 1.3) * dash,
                winnerY,
              );
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
                          profile: profile,
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
                          color: profile.color,
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
                          text: t >= 0.7 ? profile.impactYell : profile.yell,
                          impact: t >= 0.7,
                          color: profile.accent,
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
  const _YellBubble({
    super.key,
    required this.text,
    required this.impact,
    required this.color,
  });

  final String text;
  final bool impact;
  final Color color;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: impact ? -0.04 : 0.025,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: impact ? color : Colors.white,
        border: Border.all(color: Colors.black, width: 4),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: color, offset: const Offset(6, 6))],
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
    required this.profile,
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
  final FinisherProfile profile;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSpeedLines(canvas);
    if (impactProgress > 0 && impactProgress < 1) {
      _paintImpact(canvas, loserCenter, impactProgress);
    }
    _paintSmiley(
      canvas,
      loserCenter,
      loser.primaryColor,
      dizzy: true,
      rotation: _usesUppercut ? uppercutProgress * 0.55 : 0,
    );
    // Weapons and hazards sit over the characters so large cutscene balls do
    // not hide mines, spikes, blades, or projectiles.
    _paintMoveEffect(canvas);
    _paintWinner(canvas);
  }

  void _paintMoveEffect(Canvas canvas) {
    final from = winnerCenter + Offset(radius * 0.65, -radius * 0.05);
    final to = Offset.lerp(from, loserCenter, hookProgress)!;
    final kind = _kind;
    if (kind != null && _paintSignatureMove(canvas, kind, from, to)) return;
    switch (profile.style) {
      case FinisherStyle.hook:
        if (hookProgress > 0 && uppercutProgress < 0.72) {
          _paintChainAndHook(canvas, from, to);
        }
      case FinisherStyle.projectile:
      case FinisherStyle.barrage:
        if (hookProgress > 0 && hookProgress < 1) {
          final shots = profile.style == FinisherStyle.barrage ? 7 : 1;
          for (var i = 0; i < shots; i++) {
            final spread = (i - (shots - 1) / 2) * radius * 0.13;
            _paintSymbol(
              canvas,
              to + Offset(0, spread),
              profile.symbol,
              radius * (profile.style == FinisherStyle.barrage ? 0.72 : 0.9),
            );
          }
        }
      case FinisherStyle.melee:
        if (uppercutProgress > 0) {
          final strike = Offset.lerp(
            loserCenter + Offset(-radius * 1.15, radius * 0.75),
            loserCenter + Offset(radius * 0.85, -radius * 0.8),
            uppercutProgress,
          )!;
          _paintItem(canvas, strike, radius * 1.35);
          final slashSprite = PowerUpSprites.effectFrame(
            AnimatedEffect.slash,
            (uppercutProgress * 4).floor().clamp(0, 3),
          );
          if (slashSprite != null) {
            _paintRaster(
              canvas,
              slashSprite,
              loserCenter,
              radius * 1.8,
              rotation: -math.pi / 4,
            );
          }
          final slash = Paint()
            ..color = profile.accent.withValues(alpha: 1 - impactProgress)
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            loserCenter + Offset(-radius * 0.8, radius * 0.8),
            loserCenter + Offset(radius * 0.8, -radius * 0.8),
            slash,
          );
        }
      case FinisherStyle.blast:
        if (hookProgress > 0 && hookProgress < 1) {
          final arc = math.sin(hookProgress * math.pi) * radius * 1.15;
          _paintItem(canvas, to - Offset(0, arc), radius * 1.55);
        }
        if (impactProgress > 0) {
          _paintExplosion(canvas, loserCenter, impactProgress);
        }
      case FinisherStyle.trap:
        if (hookProgress > 0.35) {
          _paintItem(canvas, loserCenter, radius * 1.8);
        }
      case FinisherStyle.aura:
        final ring = Paint()
          ..color = profile.color.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7;
        canvas.drawCircle(
          winnerCenter,
          radius * (1.2 + hookProgress * 1.5),
          ring,
        );
      case FinisherStyle.warp:
        final ring = Paint()
          ..color = profile.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8;
        canvas.drawOval(
          Rect.fromCenter(
            center: loserCenter,
            width: radius * (0.5 + hookProgress * 2),
            height: radius * (1.5 + hookProgress),
          ),
          ring,
        );
    }
  }

  bool _paintSignatureMove(
    Canvas canvas,
    PowerUpKind kind,
    Offset from,
    Offset to,
  ) {
    switch (kind) {
      case PowerUpKind.pistol:
        if (hookProgress > 0 && hookProgress < 1) {
          _paintBullet(canvas, to, radius * 0.22);
        }
      case PowerUpKind.shotgun:
        if (hookProgress > 0 && hookProgress < 1) {
          final pelletSprite = PowerUpSprites.projectile(
            ProjectileSprite.shotgun,
          );
          for (var i = -3; i <= 3; i++) {
            final target = loserCenter + Offset(0, i * radius * 0.34);
            final pellet = Offset.lerp(from, target, hookProgress)!;
            if (pelletSprite == null) {
              canvas.drawCircle(
                pellet,
                radius * 0.075,
                Paint()..color = profile.accent,
              );
            } else {
              _paintRaster(canvas, pelletSprite, pellet, radius * 0.3);
            }
          }
        }
      case PowerUpKind.gatling:
        if (hookProgress > 0 && hookProgress < 1) {
          // A continuous belt-fed stream: several individual rounds remain
          // visible at once instead of one stop-start burst.
          for (var i = 0; i < 8; i++) {
            final local = (hookProgress * 2.8 + i / 8) % 1.0;
            final target =
                loserCenter + Offset(0, ((i % 5) - 2) * radius * 0.12);
            _paintBullet(
              canvas,
              Offset.lerp(from, target, local)!,
              radius * 0.14,
            );
          }
          canvas.drawCircle(
            from,
            radius * (0.18 + 0.08 * math.sin(hookProgress * 80).abs()),
            Paint()..color = profile.accent,
          );
        }
      case PowerUpKind.knife:
        if (uppercutProgress > 0) {
          final thrust = Offset.lerp(
            winnerCenter + Offset(radius * 0.9, 0),
            loserCenter - Offset(radius * 0.65, 0),
            uppercutProgress,
          )!;
          _paintItem(canvas, thrust, radius * 1.45);
          canvas.drawLine(
            thrust - Offset(radius * 0.9, 0),
            thrust,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..strokeWidth = 7
              ..strokeCap = StrokeCap.round,
          );
        }
      case PowerUpKind.sword:
        if (uppercutProgress > 0) {
          final rect = Rect.fromCenter(
            center: loserCenter,
            width: radius * 2.5,
            height: radius * 2.5,
          );
          canvas.drawArc(
            rect,
            math.pi * 0.75,
            math.pi * 1.2 * uppercutProgress,
            false,
            Paint()
              ..color = profile.accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10
              ..strokeCap = StrokeCap.round,
          );
          final blade =
              loserCenter +
              Offset.fromDirection(
                math.pi * (0.75 + 1.2 * uppercutProgress),
                radius * 1.25,
              );
          _paintItem(canvas, blade, radius * 1.65);
        }
      case PowerUpKind.shield:
        if (uppercutProgress > 0) {
          final bash = Offset.lerp(
            winnerCenter + Offset(radius, 0),
            loserCenter - Offset(radius * 0.65, 0),
            uppercutProgress,
          )!;
          _paintItem(canvas, bash, radius * 2.0);
        }
      case PowerUpKind.mine:
      case PowerUpKind.phaseMine:
        if (hookProgress > 0.18) {
          _paintItem(
            canvas,
            loserCenter + Offset(0, radius * 1.05),
            radius * 2.1,
          );
        }
        if (impactProgress > 0) {
          _paintExplosion(canvas, loserCenter, impactProgress);
        }
      case PowerUpKind.grenade:
      case PowerUpKind.molotov:
        if (hookProgress > 0 && hookProgress < 1) {
          final arc = math.sin(hookProgress * math.pi) * radius * 1.4;
          _paintItem(canvas, to - Offset(0, arc), radius * 1.65);
        }
        if (impactProgress > 0) {
          _paintExplosion(canvas, loserCenter, impactProgress);
          if (kind == PowerUpKind.molotov) {
            for (var i = 0; i < 9; i++) {
              final fireSprite = ArenaEffectLibrary.frame(
                ArenaEffectKind.flame,
                (impactProgress * 12).floor() + i,
              );
              final angle = i * math.pi * 2 / 9;
              final flame =
                  loserCenter + Offset.fromDirection(angle, radius * 1.4);
              final at = flame - Offset(0, radius * 0.35 * impactProgress);
              if (fireSprite == null) {
                canvas.drawCircle(
                  at,
                  radius * 0.18,
                  Paint()..color = i.isEven ? profile.color : profile.accent,
                );
              } else {
                _paintRaster(
                  canvas,
                  fireSprite,
                  at,
                  radius * 0.62,
                  rotation: angle + math.pi / 2,
                );
              }
            }
          }
        }
      case PowerUpKind.hook:
        if (hookProgress > 0 && uppercutProgress < 0.72) {
          _paintChainAndHook(canvas, from, to);
        }
      case PowerUpKind.threadHarpoon:
        if (hookProgress > 0) {
          for (var i = -2; i <= 2; i++) {
            final start = from + Offset(0, i * radius * 0.15);
            final end = Offset.lerp(
              start,
              loserCenter + Offset(0, i * radius * 0.28),
              hookProgress,
            )!;
            canvas.drawLine(
              start,
              end,
              Paint()
                ..color = i.isEven ? profile.color : profile.accent
                ..strokeWidth = 4
                ..strokeCap = StrokeCap.round,
            );
          }
          if (hookProgress < 1) _paintItem(canvas, to, radius * 1.25);
        }
      case PowerUpKind.ricochetDisc:
        if (hookProgress > 0 && hookProgress < 1) {
          final banner = Offset((from.dx + loserCenter.dx) / 2, radius * 0.35);
          final disc = hookProgress < 0.5
              ? Offset.lerp(from, banner, hookProgress * 2)!
              : Offset.lerp(banner, loserCenter, (hookProgress - 0.5) * 2)!;
          canvas.drawLine(
            from,
            banner,
            Paint()
              ..color = profile.color.withValues(alpha: 0.45)
              ..strokeWidth = 3,
          );
          canvas.drawLine(
            banner,
            loserCenter,
            Paint()
              ..color = profile.color.withValues(alpha: 0.45)
              ..strokeWidth = 3,
          );
          _paintItem(canvas, disc, radius * 1.25);
        }
      case PowerUpKind.orbitingFlail:
        if (hookProgress > 0) {
          final angle = hookProgress * math.pi * 4;
          final orbit =
              winnerCenter + Offset.fromDirection(angle, radius * 1.75);
          final head = hookProgress < 0.72
              ? orbit
              : Offset.lerp(orbit, loserCenter, (hookProgress - 0.72) / 0.28)!;
          canvas.drawLine(
            winnerCenter,
            head,
            Paint()
              ..color = const Color(0xFFDCE5EC)
              ..strokeWidth = 6,
          );
          _paintItem(canvas, head, radius * 1.45);
        }
      case PowerUpKind.prismLaser:
        if (hookProgress > 0) {
          const colors = [
            Colors.red,
            Colors.orange,
            Colors.yellow,
            Colors.green,
            Colors.cyan,
            Colors.purple,
          ];
          for (var i = 0; i < colors.length; i++) {
            canvas.drawLine(
              from + Offset(0, (i - 2.5) * 3),
              Offset.lerp(
                from,
                loserCenter + Offset(0, (i - 2.5) * radius * 0.2),
                hookProgress,
              )!,
              Paint()
                ..color = colors[i]
                ..strokeWidth = 5,
            );
          }
        }
      case PowerUpKind.swapCannon:
        final ring = Paint()
          ..color = profile.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8;
        canvas.drawCircle(
          winnerCenter,
          radius * (1.15 + hookProgress * 0.25),
          ring,
        );
        canvas.drawCircle(
          loserCenter,
          radius * (1.15 + hookProgress * 0.25),
          ring..color = profile.accent,
        );
        if (hookProgress > 0.25) {
          _paintArrow(canvas, winnerCenter, loserCenter, profile.accent);
          _paintArrow(canvas, loserCenter, winnerCenter, profile.color);
        }
      case PowerUpKind.spikeWall:
        if (hookProgress > 0.18) {
          _paintItem(
            canvas,
            loserCenter + Offset(0, radius * 0.7),
            radius * 2.7,
          );
        }
      case PowerUpKind.bow:
        if (hookProgress > 0) {
          for (var i = -2; i <= 2; i++) {
            final delay = i.abs() * 0.035;
            final p = ((hookProgress - delay) / (1 - delay)).clamp(0.0, 1.0);
            final start = from + Offset(0, i * radius * 0.08);
            final x = i * radius * 0.24;
            final y = -math.sqrt(
              math.max(0, radius * radius * 0.82 * 0.82 - x * x),
            );
            final end = loserCenter + Offset(x, y);
            final point =
                Offset.lerp(start, end, p)! -
                Offset(0, math.sin(p * math.pi) * radius * 2.2);
            final towardBall = loserCenter - point;
            final angle = math.atan2(towardBall.dy, towardBall.dx);
            _paintArrowGlyph(canvas, point, profile.accent, angle: angle);
          }
        }
      case PowerUpKind.rocketLauncher:
        if (hookProgress > 0 && hookProgress < 1) {
          final missile = PowerUpSprites.rocketMissile;
          final arc = math.sin(hookProgress * math.pi) * radius * 0.45;
          final point = to - Offset(0, arc);
          final direction = loserCenter - point;
          final angle = math.atan2(direction.dy, direction.dx);
          if (missile != null) {
            final pulse = 1 + math.sin(hookProgress * math.pi * 28) * 0.05;
            _paintRaster(
              canvas,
              missile,
              point,
              radius * 1.3 * pulse,
              rotation: angle,
            );
          } else {
            _paintItem(canvas, point, radius * 1.3);
          }
        }
        if (impactProgress > 0) {
          _paintExplosion(canvas, loserCenter, impactProgress);
        }
      default:
        return false;
    }
    return true;
  }

  void _paintBullet(Canvas canvas, Offset center, double size) {
    final projectile = PowerUpSprites.projectile(
      _kind == PowerUpKind.gatling
          ? ProjectileSprite.gatling
          : ProjectileSprite.pistol,
    );
    if (projectile != null) {
      _paintRaster(canvas, projectile, center, size * 3.2);
      return;
    }
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size * 2.4, height: size),
      Radius.circular(size / 2),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFFD9B45B));
    canvas.drawLine(
      center - Offset(size * 1.7, 0),
      center - Offset(size * 0.8, 0),
      Paint()
        ..color = const Color(0xFFFFE89A).withValues(alpha: 0.65)
        ..strokeWidth = size * 0.45,
    );
  }

  void _paintArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final mid = Offset.lerp(from, to, 0.5)!;
    canvas.drawLine(
      from,
      mid,
      Paint()
        ..color = color
        ..strokeWidth = 5,
    );
    _paintArrowGlyph(canvas, mid, color);
  }

  void _paintArrowGlyph(
    Canvas canvas,
    Offset point,
    Color color, {
    double angle = 0,
  }) {
    final sprite = PowerUpSprites.projectile(ProjectileSprite.bow);
    if (sprite != null) {
      _paintRaster(canvas, sprite, point, radius * 0.95, rotation: angle);
      return;
    }
    canvas.save();
    canvas.translate(point.dx, point.dy);
    canvas.rotate(angle);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final length = radius * 0.72;
    final tail = Offset(-length, 0);
    canvas.drawLine(tail, Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(-1, -0.7) * radius * 0.2, paint);
    canvas.drawLine(Offset.zero, const Offset(-1, 0.7) * radius * 0.2, paint);
    canvas.restore();
  }

  bool get _usesUppercut => profile.move == 'Hook';

  PowerUpKind? get _kind {
    for (final kind in PowerUpKind.values) {
      if (kind.label == profile.move) return kind;
    }
    return null;
  }

  void _paintItem(Canvas canvas, Offset center, double size) {
    final kind = _kind;
    if (kind == null) {
      _paintSymbol(canvas, center, profile.symbol, size * 0.7);
      return;
    }
    final sprite = PowerUpSprites.of(kind);
    if (sprite == null) {
      PowerUpSprites.paintIcon(
        canvas,
        kind,
        Rect.fromCenter(center: center, width: size, height: size),
      );
    } else {
      _paintRaster(canvas, sprite, center, size / 2);
    }
  }

  void _paintExplosion(Canvas canvas, Offset center, double progress) {
    final burst = Curves.easeOut.transform(progress);
    final fade = 1 - progress;
    final sprite = ArenaEffectLibrary.frame(
      ArenaEffectKind.explosion,
      (progress * 8).floor(),
    );
    if (sprite != null) {
      _paintRaster(
        canvas,
        sprite,
        center,
        radius * (0.8 + burst * 2.5),
        opacity: fade,
      );
      return;
    }
    canvas.drawCircle(
      center,
      radius * (0.7 + burst * 2.5),
      Paint()..color = profile.color.withValues(alpha: fade * 0.78),
    );
    canvas.drawCircle(
      center,
      radius * (0.3 + burst * 1.55),
      Paint()..color = profile.accent.withValues(alpha: fade * 0.95),
    );
  }

  void _paintRaster(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double half, {
    double rotation = 0,
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2),
      Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(
          Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
          BlendMode.modulate,
        ),
    );
    canvas.restore();
  }

  void _paintSymbol(Canvas canvas, Offset center, String symbol, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: profile.accent,
          fontSize: size,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
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
    final raisedGlove =
        glove -
        Offset(0, (_usesUppercut ? uppercutProgress : 0) * radius * 1.22);
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
    final kind = _kind;
    if (kind != null && kind.isWeapon) {
      // Weapons are staged against the cinematic ball, not at their much
      // smaller in-arena pickup size. A thrown grenade leaves the hand.
      final thrown =
          profile.style == FinisherStyle.blast && hookProgress > 0.08;
      if (!thrown) {
        _paintItem(
          canvas,
          raisedGlove + Offset(radius * 0.38, -radius * 0.18),
          radius * 1.35,
        );
      }
    }
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
      ..color = profile.accent.withValues(alpha: alpha)
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
      old.impactProgress != impactProgress ||
      old.profile != profile;
}
