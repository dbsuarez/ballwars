import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../application/match_simulation_controller.dart';
import '../domain/simulation_state.dart';
import '../../match_setup/domain/match_config.dart';
import 'arena_canvas.dart';
import 'scoreboard_overlay.dart';
import 'widgets/match_status_header.dart';
import 'winner_modal.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_management/data/local_ball_repository.dart';
import '../../replay_export/data/video_encoder.dart';
import '../../replay_export/data/video_export_backend.dart';
import '../../replay_export/domain/replay_link.dart';
import '../../replay_export/presentation/export_video_dialog.dart';
import '../../replay_export/presentation/replay_frame_painter.dart';

class ArenaBattleScreen extends StatefulWidget {
  final MatchConfig config;
  final int? seed;

  const ArenaBattleScreen({super.key, required this.config, this.seed});

  @override
  State<ArenaBattleScreen> createState() => _ArenaBattleScreenState();
}

class _ArenaBattleScreenState extends State<ArenaBattleScreen> with TickerProviderStateMixin {
  static const double _arenaRadius = 260.0;

  late MatchSimulationController _controller;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  // True right after (re)starting a match: the underlying Ticker's clock
  // keeps running across a restart even though the match itself is fresh,
  // so the next tick must just rebase _lastElapsed instead of computing a
  // huge dt from the old elapsed time.
  bool _skipNextDelta = true;
  double _rimAngle = 0.0;
  late SimulationState _state;
  bool _isPaused = false;

  // Null where this platform can't export video yet (hides SAVE VIDEO).
  final VideoExportBackend? _videoExport = createVideoExportBackend();

  // Lose-out dissolution animation
  late AnimationController _dissolveController;
  bool _showDissolve = false;
  CustomBall? _loserBall;
  CustomBall? _winnerBall;
  bool _dissolveComplete = false;

  // A beat after the last line is cut before the loser dissolves and the
  // winner banner shows. [_matchGeneration] cancels it if RETRY is pressed.
  static const Duration _endPause = Duration(milliseconds: 1200);
  // The runner-up shown big in the arena before the winner card.
  static const Duration _loserShowDuration = Duration(milliseconds: 1800);
  bool _endPending = false;
  int _matchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _dissolveController = AnimationController(duration: _loserShowDuration, vsync: this);
  }

  // Series of rounds (MatchConfig.winsNeeded): round number and wins so far.
  int _round = 1;
  final Map<String, int> _roundWins = {};
  bool _roundCounted = false;

  bool get _seriesOver => _roundWins.values.any((w) => w >= widget.config.winsNeeded);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The first match starts here (not initState) because its line colors
    // depend on the theme's background.
    if (!_started) {
      _started = true;
      _initMatch();
    }
  }

  void _initMatch() {
    // A fixed seed (replay link) gives each round its own fixed seed.
    final seed = widget.seed == null ? null : widget.seed! + _round - 1;
    _controller = MatchSimulationController(
      widget.config.contestants,
      arenaRadius: _arenaRadius,
      seed: seed,
      arenaBackground: BallWarsColors.of(context).background,
    );
    _roundCounted = false;
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
    _skipNextDelta = true;
    _showDissolve = false;
    _loserBall = null;
    _winnerBall = null;
    _dissolveComplete = false;
    _endPending = false;
    _matchGeneration++;
    _controller.preloadImages().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onTick(Duration elapsed) {
    if (_skipNextDelta) {
      _lastElapsed = elapsed;
      _skipNextDelta = false;
      return;
    }

    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || _isPaused) return;

    _controller.tick(dt * widget.config.speedMultiplier);

    // Check for win condition and start dissolve animation
    final isFinished = _state.winnerId != null;
    if (isFinished && !_endPending && !_showDissolve && !_dissolveComplete) {
      _endPending = true;
      final generation = _matchGeneration;
      bool current() => mounted && generation == _matchGeneration;
      Future.delayed(_endPause, () {
        if (!current()) return;
        setState(() {
          _winnerBall = _state.balls.firstWhere((b) => b.config.id == _state.winnerId).config;
          // The last ball knocked out (the runner-up in 3-4 ball matches).
          final loserId = _controller.lastEliminatedId;
          _loserBall = _state.balls
              .firstWhere((b) => loserId != null ? b.config.id == loserId : b.config.id != _state.winnerId)
              .config;
          _showDissolve = true;
        });
        // from: 0, so the dissolve plays again after a RETRY.
        _dissolveController.forward(from: 0).then((_) {
          if (!current()) return;
          setState(() {
            _dissolveComplete = true;
            if (!_roundCounted && _winnerBall != null) {
              _roundCounted = true;
              _roundWins.update(_winnerBall!.id, (w) => w + 1, ifAbsent: () => 1);
            }
          });
        });
      });
    }

    setState(() {
      _state = _controller.state;
    });
  }

  /// Copies a link that replays this exact match in the web app: a short
  /// `?r=<code>` link when the server is reachable, else the long one.
  Future<void> _copyReplayLink() async {
    Uri link = ReplayLink(
      seed: _controller.seed,
      speedMultiplier: widget.config.speedMultiplier,
      showEffects: widget.config.showEffects,
      contestants: widget.config.contestants,
    ).toUri(presetIds: {for (final b in LocalBallRepository.presets) b.id});
    final shortLinks = AppSettingsScope.maybeScope(context)?.shortLinks;
    if (shortLinks != null) {
      try {
        link = ReplayLink.shortUri(await shortLinks.create(link.queryParameters));
      } catch (_) {
        // Keep the long link.
      }
    }
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Replay link copied. Anyone who opens it watches this match.')));
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  /// RETRY: start the whole series over.
  void _replay() {
    setState(() {
      _isPaused = false;
      _round = 1;
      _roundWins.clear();
      _initMatch();
    });
  }

  void _nextRound() {
    setState(() {
      _isPaused = false;
      _round++;
      _initMatch();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _dissolveController.dispose();
    super.dispose();
  }

  Widget _buildDissolveAnimation() {
    return AnimatedBuilder(
      animation: _dissolveController,
      builder: (context, child) {
        // Pops in (first 20%), holds, then fades out growing (last 30%).
        final t = _dissolveController.value;
        final double opacity;
        final double scale;
        if (t < 0.2) {
          final p = Curves.easeOutBack.transform(t / 0.2);
          opacity = (t / 0.2).clamp(0.0, 1.0);
          scale = 0.6 + 0.4 * p;
        } else if (t < 0.7) {
          opacity = 1;
          scale = 1;
        } else {
          final p = (t - 0.7) / 0.3;
          opacity = 1 - p;
          scale = 1 + 0.3 * p;
        }

        return Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: SizedBox.square(
                  dimension: 200,
                  child: CustomPaint(
                    foregroundPainter: _LoserCrossPainter(t),
                    child: CircularBallPreview(ball: _loserBall!, size: 200),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final headline = AppSettingsScope.of(context).headline;
    final finished = _state.winnerId != null;
    final roundLabel = widget.config.winsNeeded > 1
        ? 'ROUND $_round · FIRST TO ${widget.config.winsNeeded}'
        : 'ROUND $_round';
    // Shrinks rather than pushing the buttons off a narrow row.
    final timer = Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatTime(_controller.elapsedSeconds),
            key: const Key('match-timer'),
            style: AppText.mono(28, color: c.text),
          ),
        ),
      ),
    );
    final restart = OutlinedButton(onPressed: _replay, child: const Text('Restart'));
    final pause = IconButton(
      icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      tooltip: _isPaused ? 'Play' : 'Pause',
      onPressed: _togglePause,
    );
    final scoreboard = ScoreboardOverlay(
      balls: _state.balls,
      wins: widget.config.winsNeeded > 1 ? _roundWins : null,
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxHeight >= constraints.maxWidth;
            // Side margins keep the arena off the screen edges on phones;
            // the slow-motion badge sits at the top of the arena.
            final arena = Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ArenaCanvas(
                      state: _state,
                      arenaRadius: _arenaRadius,
                      rimAngle: _rimAngle,
                      showEffects: widget.config.showEffects,
                    ),
                  ),
                  if (_state.status == MatchStatus.slowMotion)
                    const Align(alignment: Alignment.topCenter, child: SlowMotionBadge()),
                ],
              ),
            );

            final overlays = <Widget>[
              // The runner-up shown big, then the winner card.
              if (_showDissolve && !_dissolveComplete && _loserBall != null) _buildDissolveAnimation(),
              if (_dissolveComplete && _winnerBall != null)
                Positioned.fill(
                  child: WinnerModal(
                    winner: _winnerBall!,
                    durationSeconds: _controller.elapsedSeconds,
                    onSaveVideo: _videoExport == null
                        ? null
                        : () => ExportVideoDialog.show(
                            context,
                            contestants: widget.config.contestants,
                            seed: _controller.seed,
                            arenaRadius: _arenaRadius,
                            speedMultiplier: widget.config.speedMultiplier,
                            showEffects: widget.config.showEffects,
                            headline: headline,
                            colors: c,
                            backend: _videoExport,
                          ),
                    onShareLink: _copyReplayLink,
                    onReplay: _replay,
                    round: widget.config.winsNeeded > 1 ? _round : null,
                    seriesOver: _seriesOver,
                    onNextRound: _seriesOver ? null : _nextRound,
                    score: widget.config.winsNeeded > 1
                        ? [for (final b in widget.config.contestants) (b.name, _roundWins[b.id] ?? 0)]
                        : null,
                    onExit: () => Navigator.of(context).maybePop(),
                  ),
                ),
            ];

            final leave = IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Leave match',
              onPressed: () => Navigator.of(context).maybePop(),
            );

            if (isPortrait) {
              return Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Row(
                          children: [
                            leave,
                            Expanded(child: MatchStatusHeader(headline: headline, subtitle: roundLabel, dimmed: finished)),
                            pause,
                          ],
                        ),
                      ),
                      Expanded(child: arena),
                      Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 8), child: scoreboard),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                        child: Row(children: [timer, restart]),
                      ),
                    ],
                  ),
                  ...overlays,
                ],
              );
            }

            // Wide screens (web, landscape): the game takes the left half and
            // the winner card stays there, centered on the arena; the
            // headline, scores and controls sit in the right half.
            return Row(
              children: [
                Expanded(
                  child: Stack(children: [Positioned.fill(child: arena), ...overlays]),
                ),
                Container(width: 1, color: c.border),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(alignment: Alignment.centerLeft, child: leave),
                            const SizedBox(height: 8),
                            MatchStatusHeader(
                              headline: headline,
                              subtitle: roundLabel,
                              dimmed: finished,
                              align: TextAlign.start,
                            ),
                            const SizedBox(height: 28),
                            scoreboard,
                            const SizedBox(height: 28),
                            Row(children: [timer, pause, const SizedBox(width: 8), restart]),
                          ],
                        ),
                      ),
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

  static String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = seconds - m * 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }
}

/// The red X over the eliminated ball while it flashes (same as the video).
class _LoserCrossPainter extends CustomPainter {
  _LoserCrossPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) =>
      ReplayFramePainter.paintLoserCross(canvas, size.center(Offset.zero), size.shortestSide / 2, progress);

  @override
  bool shouldRepaint(_LoserCrossPainter old) => old.progress != progress;
}
