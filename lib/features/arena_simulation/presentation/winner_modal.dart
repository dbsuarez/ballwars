import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import 'confetti_painter.dart';

class WinnerModal extends StatefulWidget {
  final CustomBall winner;
  final double? durationSeconds;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  /// Shows a SAVE VIDEO button when set (only where video export works).
  final VoidCallback? onSaveVideo;

  /// Shows a SHARE LINK button when set.
  final VoidCallback? onShareLink;

  /// Multi-round series: the round just played, the score so far (name,
  /// wins) and whether a ball has now won the series. While it isn't over,
  /// [onNextRound] shows NEXT ROUND as the main button.
  final int? round;
  final List<(String, int)>? score;
  final bool seriesOver;
  final VoidCallback? onNextRound;

  const WinnerModal({
    super.key,
    required this.winner,
    this.durationSeconds,
    required this.onReplay,
    required this.onExit,
    this.onSaveVideo,
    this.onShareLink,
    this.round,
    this.score,
    this.seriesOver = true,
    this.onNextRound,
  });

  @override
  State<WinnerModal> createState() => _WinnerModalState();
}

class _WinnerModalState extends State<WinnerModal> with TickerProviderStateMixin {
  late final AnimationController _controller;
  // Drives the confetti clock (seconds = value * 600); long enough to never end.
  late final AnimationController _confetti;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();
    _confetti = AnimationController(duration: const Duration(minutes: 10), vsync: this)..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dimmed HUD background at ~40% opacity. Taps pass through it so the
        // screen's own controls (RETRY under the scoreboard) keep working.
        Positioned.fill(
          child: IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.4))),
        ),
        // Faint tiled watermark background (behind the card, never takes taps:
        // a full-size CustomPaint otherwise swallows every tap on the screen)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _WatermarkPainter(text: 'BALLWARS')),
          ),
        ),
        // Confetti falling behind the card
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(painter: ConfettiPainter(_confetti.value * 600)),
            ),
          ),
        ),
        // Winner card centered; shrinks to fit small areas (e.g. the left half
        // of a wide screen) instead of overflowing.
        Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Winner ball scaled up, keeps physics-stripe look
                          CircularBallPreview(ball: widget.winner, size: 220),
                          const SizedBox(height: 24),
                          // "<Name>" then "WINS!" on the next line
                          Text(
                            widget.winner.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.0,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.round == null
                                ? 'WINS!'
                                : widget.seriesOver
                                ? 'WINS THE SERIES!'
                                : 'WINS ROUND ${widget.round}!',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD700),
                              letterSpacing: 3.0,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Small gold trophy/star glyph
                          Icon(
                            Icons.emoji_events,
                            color: const Color(0xFFFFD700), // Gold
                            size: 32,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          if (widget.durationSeconds != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'MATCH TIME ${widget.durationSeconds!.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                          if (widget.score != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.score!.map((e) => '${e.$1}  ${e.$2}').join('   ·   '),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.onNextRound != null) ...[
                                FilledButton.icon(
                                  onPressed: widget.onNextRound,
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text('NEXT ROUND'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: widget.onReplay,
                                  icon: const Icon(Icons.replay),
                                  label: const Text('RETRY'),
                                ),
                              ] else
                                FilledButton.icon(
                                  onPressed: widget.onReplay,
                                  icon: const Icon(Icons.replay),
                                  label: const Text('RETRY'),
                                ),
                              const SizedBox(width: 12),
                              OutlinedButton(onPressed: widget.onExit, child: const Text('EXIT')),
                            ],
                          ),
                          if (widget.onSaveVideo != null || widget.onShareLink != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: [
                                if (widget.onSaveVideo != null)
                                  OutlinedButton.icon(
                                    onPressed: widget.onSaveVideo,
                                    icon: const Icon(Icons.movie),
                                    label: const Text('SAVE VIDEO'),
                                  ),
                                if (widget.onShareLink != null)
                                  OutlinedButton.icon(
                                    onPressed: widget.onShareLink,
                                    icon: const Icon(Icons.link),
                                    label: const Text('SHARE LINK'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;
  final double fontSize = 200;
  final double spacing = 250;

  _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 200,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.02),
          letterSpacing: 20,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    // Tile the watermark
    for (double x = -textWidth; x < size.width + textWidth; x += 250) {
      for (double y = -textHeight; y < size.height + textHeight; y += 250) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-math.pi / 6); // Slight diagonal tilt
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
