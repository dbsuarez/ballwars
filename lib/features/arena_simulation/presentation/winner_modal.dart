import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../settings/presentation/app_settings_scope.dart';
import 'confetti_painter.dart';

typedef SeriesStanding = ({CustomBall ball, int wins, int losses, double hp});

List<SeriesStanding> rankSeriesStandings(List<SeriesStanding> standings) =>
    [...standings]..sort((a, b) {
      final wins = b.wins.compareTo(a.wins);
      if (wins != 0) return wins;
      final losses = a.losses.compareTo(b.losses);
      if (losses != 0) return losses;
      final hp = b.hp.compareTo(a.hp);
      if (hp != 0) return hp;
      return a.ball.name.toLowerCase().compareTo(b.ball.name.toLowerCase());
    });

/// The end-of-round card over the arena: the winner, the result, and what
/// to do next. Confetti falls behind it.
class WinnerModal extends StatefulWidget {
  final CustomBall winner;
  final double? durationSeconds;
  final String? winningMove;

  /// Final Mayhem knockouts for every contestant, including zero scores.
  final List<(CustomBall, int, double)>? mayhemTally;

  /// Yes or No: the question the match answered; the card then shows the winner as the answer.
  final String? question;

  /// Replay: watch this exact match again.
  final VoidCallback onReplay;

  /// Replays only the winning finishing move when one has a cinematic.
  final VoidCallback? onReplayFinisher;

  /// Play again (or Start over in a series): a new simulation.
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  /// Shows a SAVE VIDEO button when set (only where video export works).
  final VoidCallback? onSaveVideo;

  /// Shows a SHARE button when set.
  final VoidCallback? onShareLink;
  final VoidCallback? onSaveReplay;

  /// Multi-round series: the round just played, the score so far (name,
  /// wins, losses and remaining HP) and whether a ball has now won the series. While it isn't over,
  /// [onNextRound] shows NEXT ROUND as the main button.
  final int? round;
  final List<SeriesStanding>? score;
  final bool seriesOver;
  final VoidCallback? onNextRound;

  /// Confetti; off when the player turned particle effects off.
  final bool showEffects;

  /// When set, asks under the buttons whether the game runs slow and effects
  /// should go off. Called with (turn effects off, don't ask again); the
  /// question then disappears.
  final void Function(bool turnOff, bool dontAskAgain)? onSlowAnswer;

  const WinnerModal({
    super.key,
    required this.winner,
    this.durationSeconds,
    this.winningMove,
    this.mayhemTally,
    this.question,
    required this.onReplay,
    this.onReplayFinisher,
    required this.onPlayAgain,
    required this.onExit,
    this.onSaveVideo,
    this.onShareLink,
    this.onSaveReplay,
    this.round,
    this.score,
    this.seriesOver = true,
    this.onNextRound,
    this.showEffects = true,
    this.onSlowAnswer,
  });

  /// How long the confetti falls before it stops (its last second fades out). Then nothing on the card
  /// animates, so phones stop redrawing it.
  static const Duration confettiDuration = Duration(seconds: 13);

  @override
  State<WinnerModal> createState() => _WinnerModalState();
}

class _WinnerModalState extends State<WinnerModal>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;
  // Drives the confetti clock (seconds = value * 600); long enough to never end.
  late final AnimationController _confetti;

  bool _dontAskAgain = false;
  bool _slowAnswered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _opacityAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.6, curve: Curves.easeOut),
    );
    _controller.forward();
    _confetti = AnimationController(
      duration: WinnerModal.confettiDuration,
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _answerSlow(bool turnOff) {
    setState(() => _slowAnswered = true);
    widget.onSlowAnswer!(turnOff, _dontAskAgain);
  }

  /// "Running slow? Turn off effects" with Yes / No and "Don't ask again".
  Widget _slowPrompt(BallWarsColors c) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: c.surfaceHigh,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Game running slow?',
            style: AppText.ui(14, FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: 2),
          Text(
            'Turning off particle effects (sparks and confetti) can make it smoother.',
            style: AppText.ui(12, FontWeight.w500, color: c.muted, height: 1.4),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _dontAskAgain,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) =>
                            setState(() => _dontAskAgain = v ?? false),
                      ),
                      Flexible(
                        child: Text(
                          "Don't ask again",
                          style: AppText.ui(
                            12,
                            FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _answerSlow(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => _answerSlow(true),
                child: const Text('Turn off'),
              ),
            ],
          ),
        ],
      ),
    );
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

  Widget _mayhemResults(BuildContext context) {
    final c = BallWarsColors.of(context);
    final original = widget.mayhemTally!;
    final rows = [...original]
      ..sort((a, b) {
        final score = b.$2.compareTo(a.$2);
        if (score != 0) return score;
        final life = b.$3.compareTo(a.$3);
        if (life != 0) return life;
        return original.indexOf(a).compareTo(original.indexOf(b));
      });

    return Card(
      key: const ValueKey('mayhem-final-tally'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MAYHEM TALLY', style: AppText.mono(12, color: c.muted)),
            Text(
              'Knockouts first / remaining life breaks ties',
              style: AppText.ui(11, FontWeight.w500, color: c.muted),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < rows.length; i++)
              Builder(
                builder: (context) {
                  final (ball, knockouts, life) = rows[i];
                  final rank =
                      rows.indexWhere(
                        (row) => row.$2 == knockouts && row.$3 == life,
                      ) +
                      1;
                  return Padding(
                    key: ValueKey('mayhem-result-${ball.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$rank',
                            style: AppText.mono(12, color: c.muted),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ball.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ball.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              13,
                              FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 22,
                          child: ball.id == widget.winner.id
                              ? Icon(
                                  Icons.emoji_events,
                                  size: 16,
                                  color: c.text,
                                )
                              : null,
                        ),
                        SizedBox(
                          width: 54,
                          child: Text(
                            '$knockouts KOs',
                            textAlign: TextAlign.right,
                            style: AppText.mono(12, color: c.text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            '${life.toStringAsFixed(1)} HP',
                            textAlign: TextAlign.right,
                            style: AppText.mono(12, color: c.muted),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
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
          child: IgnorePointer(
            child: ColoredBox(color: c.background.withValues(alpha: 0.9)),
          ),
        ),
        // Faint tiled watermark behind the card (admin setting; never takes taps).
        if (settings.watermarkEnabled)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WatermarkPainter(
                  text: settings.watermarkText,
                  color: c.text,
                ),
              ),
            ),
          ),
        if (widget.showEffects)
          Positioned.fill(
            child: IgnorePointer(
              // Its own layer: the falling confetti repaints every frame, the
              // watermark and the card behind it don't have to.
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _confetti,
                  builder: (context, _) {
                    final seconds =
                        _confetti.value *
                        WinnerModal.confettiDuration.inMilliseconds /
                        1000;
                    final left =
                        WinnerModal.confettiDuration.inMilliseconds / 1000 -
                        seconds;
                    if (left <= 0) return const SizedBox.shrink();
                    return CustomPaint(
                      painter: ConfettiPainter(
                        seconds,
                        opacity: left.clamp(0.0, 1.0),
                      ),
                    );
                  },
                ),
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
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * _scaleAnim.value,
                    child: child,
                  ),
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
                            widget.seriesOver
                                ? 'SERIES · ${widget.round} ROUNDS'
                                : 'ROUND ${widget.round}',
                            textAlign: TextAlign.center,
                            style: AppText.mono(
                              11,
                              color: c.muted,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      Center(
                        child: CircularBallPreview(
                          ball: widget.winner,
                          size: 160,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Text(
                        widget.winner.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          38,
                          FontWeight.w800,
                          color: c.text,
                          height: 1.05,
                          letterSpacing: -0.6,
                        ),
                      ),
                      if (widget.question != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.question!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(
                            14,
                            FontWeight.w600,
                            color: c.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Answer: ${widget.winner.name}',
                          textAlign: TextAlign.center,
                          style: AppText.ui(20, FontWeight.w800, color: c.text),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _result,
                        textAlign: TextAlign.center,
                        style: AppText.ui(18, FontWeight.w600, color: c.muted),
                      ),
                      if (widget.winningMove != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Winning move: ${widget.winningMove}',
                          textAlign: TextAlign.center,
                          style: AppText.ui(14, FontWeight.w700, color: c.text),
                        ),
                      ],
                      if (widget.onReplayFinisher != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const ValueKey('replay-finisher'),
                          onPressed: widget.onReplayFinisher,
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Replay finisher'),
                        ),
                      ],
                      if (widget.onSaveReplay != null) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          key: const ValueKey('save-replay'),
                          onPressed: widget.onSaveReplay,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: const Text('Save replay'),
                        ),
                      ],
                      if (score != null) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: c.border),
                            ),
                            child: Text(
                              rankSeriesStandings(score)
                                  .map(
                                    (entry) =>
                                        '${entry.ball.name}  ${entry.wins}W-${entry.losses}L  ${entry.hp.toStringAsFixed(0)} HP',
                                  )
                                  .join('   ·   '),
                              textAlign: TextAlign.center,
                              style: AppText.mono(14, color: c.text),
                            ),
                          ),
                        ),
                      ],
                      if (widget.mayhemTally != null) _mayhemResults(context),
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
                        FilledButton(
                          onPressed: widget.onNextRound,
                          child: const Text('Next round'),
                        )
                      else
                        FilledButton(
                          onPressed: widget.onPlayAgain,
                          child: const Text('Play again'),
                        ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onReplay,
                                child: const Text('Replay'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            if (widget.onSaveVideo != null) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onSaveVideo,
                                  child: const Text('Save video'),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (widget.onShareLink != null) ...[
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: widget.onShareLink,
                                  child: const Text('Share'),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: OutlinedButton(
                                onPressed: widget.onExit,
                                child: const Text('Exit'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.onNextRound != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            onPressed: widget.onPlayAgain,
                            child: const Text('Start over'),
                          ),
                        ),
                      if (widget.onSlowAnswer != null && !_slowAnswered)
                        _slowPrompt(c),
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
      text: TextSpan(
        text: text,
        style: AppText.ui(
          44,
          FontWeight.w800,
          color: color.withValues(alpha: 0.04),
        ),
      ),
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
      for (
        var x = -reach + (row.isOdd ? stepX / 2 : 0);
        x < reach;
        x += stepX
      ) {
        painter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter oldDelegate) =>
      oldDelegate.text != text || oldDelegate.color != color;
}
