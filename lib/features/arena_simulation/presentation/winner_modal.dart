import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../settings/presentation/app_settings_scope.dart';
import 'confetti_painter.dart';

/// The end-of-round card over the arena: the winner, the result, and what
/// to do next. Confetti falls behind it.
class WinnerModal extends StatefulWidget {
  final CustomBall winner;
  final double? durationSeconds;
  final VoidCallback onReplay;
  final VoidCallback onExit;

  /// Shows a SAVE VIDEO button when set (only where video export works).
  final VoidCallback? onSaveVideo;

  /// Shows a SHARE button when set.
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
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  // Drives the confetti clock (seconds = value * 600); long enough to never end.
  late final AnimationController _confetti;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
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

  String get _result {
    if (widget.round == null) return 'wins!';
    if (widget.seriesOver) return 'wins the series';
    return 'wins round ${widget.round}';
  }

  String _time(double seconds) {
    final m = seconds ~/ 60;
    return '$m:${(seconds - m * 60).toStringAsFixed(1).padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final settings = AppSettingsScope.of(context);
    final score = widget.score;
    return Stack(
      children: [
        // Covers the arena; taps pass through so the screen's own controls
        // (e.g. Restart beside it on wide screens) keep working.
        Positioned.fill(
          child: IgnorePointer(child: ColoredBox(color: c.background.withValues(alpha: 0.9))),
        ),
        // Faint tiled watermark behind the card (admin setting; never takes taps).
        if (settings.watermarkEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _WatermarkPainter(text: settings.watermarkText, color: c.text)),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(painter: ConfettiPainter(_confetti.value * 600)),
            ),
          ),
        ),
        // Shrinks to fit small areas (e.g. the left half of a wide screen).
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _opacityAnim.value,
                  child: Transform.scale(scale: 0.85 + 0.15 * _scaleAnim.value, child: child),
                ),
                child: SizedBox(
                  width: 340,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.round != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text(
                            widget.seriesOver ? 'SERIES · ${widget.round} ROUNDS' : 'ROUND ${widget.round}',
                            textAlign: TextAlign.center,
                            style: AppText.mono(11, color: c.muted, letterSpacing: 1.8),
                          ),
                        ),
                      Center(child: CircularBallPreview(ball: widget.winner, size: 160)),
                      const SizedBox(height: 26),
                      Text(
                        widget.winner.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(38, FontWeight.w800, color: c.text, height: 1.05, letterSpacing: -0.6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _result,
                        textAlign: TextAlign.center,
                        style: AppText.ui(18, FontWeight.w600, color: c.muted),
                      ),
                      if (score != null) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              score.map((e) => '${e.$1}  ${e.$2}').join('   ·   '),
                              textAlign: TextAlign.center,
                              style: AppText.mono(14, color: c.text),
                            ),
                          ),
                        ),
                      ],
                      if (widget.durationSeconds != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'match time ${_time(widget.durationSeconds!)}',
                          textAlign: TextAlign.center,
                          style: AppText.mono(12, color: c.muted),
                        ),
                      ],
                      const SizedBox(height: 28),
                      if (widget.onNextRound != null)
                        FilledButton(onPressed: widget.onNextRound, child: const Text('Next round'))
                      else
                        FilledButton(onPressed: widget.onReplay, child: const Text('Play again')),
                      const SizedBox(height: 10),
                      // Up to four secondary actions share one row: tighter padding.
                      OutlinedButtonTheme(
                        data: OutlinedButtonThemeData(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 46),
                            side: BorderSide(color: c.border),
                            foregroundColor: c.text,
                            textStyle: AppText.ui(13, FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (widget.onNextRound != null) ...[
                              Expanded(
                                child: OutlinedButton(onPressed: widget.onReplay, child: const Text('Restart')),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (widget.onSaveVideo != null) ...[
                              Expanded(
                                child: OutlinedButton(onPressed: widget.onSaveVideo, child: const Text('Save video')),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (widget.onShareLink != null) ...[
                              Expanded(
                                child: OutlinedButton(onPressed: widget.onShareLink, child: const Text('Share')),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: OutlinedButton(onPressed: widget.onExit, child: const Text('Exit')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The owner's name tiled diagonally across the card's background.
class _WatermarkPainter extends CustomPainter {
  final String text;
  final Color color;

  _WatermarkPainter({required this.text, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: AppText.ui(44, FontWeight.w800, color: color.withValues(alpha: 0.04))),
      textDirection: TextDirection.ltr,
    )..layout();
    final stepX = painter.width + 48;
    const stepY = 96.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-math.pi / 9);
    final reach = size.longestSide;
    var row = 0;
    for (var y = -reach; y < reach; y += stepY, row++) {
      // Every other row is shifted half a step, like bricks.
      for (var x = -reach + (row.isOdd ? stepX / 2 : 0); x < reach; x += stepX) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) => oldDelegate.text != text || oldDelegate.color != color;
}
