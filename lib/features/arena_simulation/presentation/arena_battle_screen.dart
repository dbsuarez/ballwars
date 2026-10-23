import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../application/match_simulation_controller.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import '../../match_setup/domain/match_config.dart';
import 'power_up_sprites.dart';
import 'ball_face_expression.dart';
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
import '../../../core/audio/game_audio.dart';
import '../../settings/data/effects_prefs.dart';

class ArenaBattleScreen extends StatefulWidget {
  final MatchConfig config;
  final int? seed;

  const ArenaBattleScreen({super.key, required this.config, this.seed});

  @override
  State<ArenaBattleScreen> createState() => _ArenaBattleScreenState();
}

class _ArenaBattleScreenState extends State<ArenaBattleScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // Particle effects: start as the match was set up; the winner card can
  // turn them off for the rest of the series ("Game running slow?").
  late bool _showEffects = widget.config.showEffects;
  bool _askSlow = false;

  final GameAudio _audio = GameAudio.instance;

  // Performance: each frame bumps [_frame] instead of calling setState, so
  // only the arena (repaint) and the few live readouts (scores, timer,
  // badges) update; nothing else rebuilds. The arena repaints only when the
  // simulation stepped, or effects are still animating (at most ~60 fps):
  // the simulation runs at 60 steps/s, so painting at a 120-144 Hz display
  // rate would mostly redraw identical frames.
  final ValueNotifier<int> _frame = ValueNotifier(0);
  int _paintedStep = -1;
  Duration _lastPaint = Duration.zero;
  static const Duration _minFrameGap = Duration(microseconds: 16000);
  // Hit counts already played as sounds.
  int _heardWallHits = 0;
  int _heardBallHits = 0;
  // Power-up events already played as sounds (shots, hits, slashes, blocks, blasts, pickups).
  var _heardPowerUps = (0, 0, 0, 0, 0, 0);
  var _heardGatling = 0;

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
    WidgetsBinding.instance.addObserver(this);
    _audio.stopMenuMusic(); // The match music takes over until we leave.
    _ticker = createTicker(_onTick)..start();
    _dissolveController = AnimationController(
      duration: _loserShowDuration,
      vsync: this,
    );
    EffectsPrefs.askWhenSlow().then((ask) {
      if (mounted) setState(() => _askSlow = ask);
    });
  }

  void _answerSlow(bool turnOff, bool dontAskAgain) {
    setState(() {
      _askSlow = false; // Asked once per series at most.
      if (turnOff) _showEffects = false;
    });
    if (turnOff) EffectsPrefs.setEffectsOn(false);
    if (dontAskAgain) EffectsPrefs.setAskWhenSlow(false);
  }

  // Series of rounds (MatchConfig.winsNeeded): round number and wins so far.
  int _round = 1;
  final Map<String, int> _roundWins = {};
  bool _roundCounted = false;

  bool get _seriesOver =>
      _roundWins.values.any((w) => w >= widget.config.winsNeeded);

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

  /// Seed of the first round: the link's seed, until Play again starts fresh matches.
  late int? _seedBase = widget.seed;

  /// Starts a match. [replaySeed] re-runs a finished match exactly (Replay); it isn't counted again.
  void _initMatch({int? replaySeed}) {
    // A fixed seed (replay link) gives each round its own fixed seed.
    final seed =
        replaySeed ?? (_seedBase == null ? null : _seedBase! + _round - 1);
    _controller = MatchSimulationController(
      widget.config.contestants,
      arenaRadius: _arenaRadius,
      seed: seed,
      arenaBackground: BallWarsColors.of(context).background,
      slowMotionLines: AppSettingsScope.of(context).slowMotionLines,
      slowMotionBeforeWinSeconds: AppSettingsScope.of(
        context,
      ).slowMotionBeforeWinSeconds,
      ballScale: widget.config.ballSize.scale,
      mode: widget.config.mode,
      powerUpKinds: widget.config.powerUps,
      tuning: widget.config.tuning,
      dualWield: widget.config.dualWield,
      endlessBattle: widget.config.endlessBattle,
    );
    _roundCounted = replaySeed != null;
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
    _skipNextDelta = true;
    _showDissolve = false;
    _loserBall = null;
    _winnerBall = null;
    _dissolveComplete = false;
    _endPending = false;
    _heardWallHits = 0;
    _heardBallHits = 0;
    _heardPowerUps = (0, 0, 0, 0, 0, 0);
    _heardGatling = 0;
    _audio.startMusic();
    _matchGeneration++;
    if (widget.config.mode != MatchMode.threads) {
      PowerUpSprites.load().then((_) {
        if (mounted) setState(() {});
      });
    }
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

    if (_controller.wallHits > _heardWallHits) {
      _heardWallHits = _controller.wallHits;
      _audio.bounce();
    }
    _playPowerUpSounds();
    if (_controller.ballHits > _heardBallHits) {
      _heardBallHits = _controller.ballHits;
      _audio.collide();
    }
    _state = _controller.state;
    _audio.slowMotion = _state.status == MatchStatus.slowMotion;

    // Check for win condition and start dissolve animation
    final isFinished = _state.winnerId != null;
    if (isFinished && !_endPending && !_showDissolve && !_dissolveComplete) {
      setState(() => _endPending = true); // Dims the header right away.
      _audio.stopMusic();
      final generation = _matchGeneration;
      bool current() => mounted && generation == _matchGeneration;
      Future.delayed(_endPause, () {
        if (!current()) return;
        setState(() {
          _winnerBall = _state.balls
              .firstWhere((b) => b.config.id == _state.winnerId)
              .config;
          // The last ball knocked out (the runner-up in 3-4 ball matches).
          final loserId = _controller.lastEliminatedId;
          _loserBall = _state.balls
              .firstWhere(
                (b) => loserId != null
                    ? b.config.id == loserId
                    : b.config.id != _state.winnerId,
              )
              .config;
          _showDissolve = true;
        });
        _audio.out();
        // from: 0, so the dissolve plays again after a RETRY.
        _dissolveController.forward(from: 0).then((_) {
          if (!current()) return;
          _audio.win();
          setState(() {
            _dissolveComplete = true;
            if (!_roundCounted && _winnerBall != null) {
              _roundCounted = true;
              _roundWins.update(
                _winnerBall!.id,
                (w) => w + 1,
                ifAbsent: () => 1,
              );
            }
          });
        });
      });
    }

    final stepped = _controller.stepCount != _paintedStep;
    final animating =
        _state.floatingTexts.items.isNotEmpty ||
        (_showEffects && _state.particles.particles.isNotEmpty);
    if (stepped || (animating && elapsed - _lastPaint >= _minFrameGap)) {
      _paintedStep = _controller.stepCount;
      _lastPaint = elapsed;
      _frame.value++;
    }
  }

  /// Plays a sound for each kind of power-up event that happened since the last frame. Ten new shots at
  /// once is a shotgun blast.
  void _playPowerUpSounds() {
    final p = _controller.powerUps;
    if (p == null) return;
    final (shots, hits, slashes, blocks, blasts, pickups) = _heardPowerUps;
    if (p.gatlingShots > _heardGatling) {
      _audio.gatling();
    } else if (p.shots > shots) {
      p.shots - shots >= 5 ? _audio.shotgun() : _audio.shot();
    }
    _heardGatling = p.gatlingShots;
    if (p.hits > hits) _audio.hit();
    if (p.slashes > slashes) _audio.slash();
    if (p.blocks > blocks) _audio.shield();
    if (p.blasts > blasts) _audio.bomb();
    if (p.pickups > pickups) _audio.pickup();
    _heardPowerUps = (
      p.shots,
      p.hits,
      p.slashes,
      p.blocks,
      p.blasts,
      p.pickups,
    );
  }

  /// Back from the background (phone unlocked): the next frame is not
  /// counted, so there's no time jump. (GameAudio pauses and resumes music.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _skipNextDelta = true;
  }

  /// Copies a link that replays this exact match in the web app: a short
  /// `?r=<code>` link when the server is reachable, else the long one.
  Future<void> _copyReplayLink() async {
    Uri link = ReplayLink(
      seed: _controller.seed,
      speedMultiplier: widget.config.speedMultiplier,
      showEffects: _showEffects,
      contestants: widget.config.contestants,
      ballSize: widget.config.ballSize,
      mode: widget.config.mode,
      question: widget.config.question,
      powerUps: widget.config.powerUps,
      tuning: widget.config.tuning,
      dualWield: widget.config.dualWield,
      endlessBattle: widget.config.endlessBattle,
    ).toUri(presetIds: {for (final b in LocalBallRepository.presets) b.id});
    final shortLinks = AppSettingsScope.maybeScope(context)?.shortLinks;
    if (shortLinks != null) {
      try {
        link = ReplayLink.shortUri(
          await shortLinks.create(link.queryParameters),
        );
      } catch (_) {
        // Keep the long link.
      }
    }
    await Clipboard.setData(ClipboardData(text: link.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Replay link copied. Anyone who opens it watches this match.',
        ),
      ),
    );
  }

  void _togglePause() {
    _audio.click();
    setState(() => _isPaused = !_isPaused);
    _isPaused ? _audio.pauseMusic() : _audio.resumeMusic();
  }

  /// Play again / New match: a new simulation (new seeds, even for a match opened from a link), and the
  /// series starts over.
  void _playAgain() {
    _audio.click();
    setState(() {
      _isPaused = false;
      _seedBase = null;
      _round = 1;
      _roundWins.clear();
      _initMatch();
    });
  }

  /// Replay: watch the match that just ended again, exactly as it played (same seed; the round isn't
  /// counted twice).
  void _replay() {
    _audio.click();
    final seed = _controller.seed;
    setState(() {
      _isPaused = false;
      _initMatch(replaySeed: seed);
    });
  }

  void _nextRound() {
    _audio.click();
    setState(() {
      _isPaused = false;
      _round++;
      _initMatch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _dissolveController.dispose();
    _frame.dispose();
    _audio.stopMusic();
    _audio.startMenuMusic();
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
    // A Yes or No question takes the headline's place.
    final headline =
        widget.config.question ?? AppSettingsScope.of(context).headline;
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
          child: ListenableBuilder(
            listenable: _frame,
            builder: (context, _) {
              final speedUp = _controller.playbackSpeedUp;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _formatTime(_controller.elapsedSeconds),
                    key: const Key('match-timer'),
                    style: AppText.mono(28, color: c.text),
                  ),
                  // Long matches play faster each minute (playback only).
                  if (speedUp > 1 && _state.status != MatchStatus.slowMotion)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        'x${speedUp == speedUp.roundToDouble() ? speedUp.round() : speedUp}',
                        key: const Key('speed-up'),
                        style: AppText.mono(14, color: c.muted),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final restart = OutlinedButton(
      onPressed: _playAgain,
      child: const Text('New match'),
    );
    final pause = IconButton(
      icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      tooltip: _isPaused ? 'Play' : 'Pause',
      onPressed: _togglePause,
    );
    final scoreboard = ListenableBuilder(
      listenable: _frame,
      builder: (context, _) => ScoreboardOverlay(
        mode: widget.config.mode,
        balls: _state.balls,
        wins: widget.config.winsNeeded > 1 ? _roundWins : null,
        eliminations: widget.config.endlessBattle
            ? _controller.eliminations
            : null,
      ),
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
                    child: RepaintBoundary(
                      child: ArenaCanvas(
                        state: _state,
                        arenaRadius: _arenaRadius,
                        rimAngle: _rimAngle,
                        showEffects: _showEffects,
                        repaint: _frame,
                        look: widget.config.look,
                      ),
                    ),
                  ),
                  // Positioned like the arena: a non-positioned child would
                  // size the Stack (to nothing, while there's no badge).
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: _frame,
                      builder: (context, _) =>
                          _state.status == MatchStatus.slowMotion
                          ? const Align(
                              alignment: Alignment.topCenter,
                              child: SlowMotionBadge(),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            );

            final overlays = <Widget>[
              // The runner-up shown big, then the winner card.
              if (_showDissolve && !_dissolveComplete && _loserBall != null)
                _buildDissolveAnimation(),
              if (_dissolveComplete && _winnerBall != null)
                Positioned.fill(
                  child: WinnerModal(
                    winner: _winnerBall!,
                    question: widget.config.question,
                    durationSeconds: _controller.elapsedSeconds,
                    onSaveVideo: _videoExport == null
                        ? null
                        : () {
                            _audio.click();
                            ExportVideoDialog.show(
                              context,
                              contestants: widget.config.contestants,
                              seed: _controller.seed,
                              arenaRadius: _arenaRadius,
                              speedMultiplier: widget.config.speedMultiplier,
                              showEffects: _showEffects,
                              slowMotionLines: AppSettingsScope.of(
                                context,
                              ).slowMotionLines,
                              slowMotionBeforeWinSeconds: AppSettingsScope.of(
                                context,
                              ).slowMotionBeforeWinSeconds,
                              ballScale: widget.config.ballSize.scale,
                              mode: widget.config.mode,
                              look: widget.config.look,
                              powerUps: widget.config.powerUps,
                              tuning: widget.config.tuning,
                              headline: headline,
                              colors: c,
                              backend: _videoExport,
                            );
                          },
                    onShareLink: () {
                      _audio.click();
                      _copyReplayLink();
                    },
                    onReplay: _replay,
                    onPlayAgain: _playAgain,
                    round: widget.config.winsNeeded > 1 ? _round : null,
                    seriesOver: _seriesOver,
                    onNextRound: _seriesOver ? null : _nextRound,
                    score: widget.config.winsNeeded > 1
                        ? [
                            for (final b in widget.config.contestants)
                              (b.name, _roundWins[b.id] ?? 0),
                          ]
                        : null,
                    onExit: () {
                      _audio.click();
                      Navigator.of(context).maybePop();
                    },
                    showEffects: _showEffects,
                    onSlowAnswer: _showEffects && _askSlow ? _answerSlow : null,
                  ),
                ),
            ];

            final leave = IconButton(
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Leave match',
              onPressed: () {
                _audio.click();
                Navigator.of(context).maybePop();
              },
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
                            Expanded(
                              child: MatchStatusHeader(
                                headline: headline,
                                subtitle: roundLabel,
                                dimmed: finished,
                              ),
                            ),
                            pause,
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                        child: ListenableBuilder(
                          listenable: _frame,
                          builder: (context, _) => _VersusHeader(
                            balls: _state.balls,
                            compact: true,
                            look: widget.config.look,
                          ),
                        ),
                      ),
                      Expanded(child: arena),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                        child: scoreboard,
                      ),
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
                  child: Stack(
                    children: [
                      Positioned.fill(child: arena),
                      ...overlays,
                    ],
                  ),
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: leave,
                            ),
                            const SizedBox(height: 8),
                            ListenableBuilder(
                              listenable: _frame,
                              builder: (context, _) => _VersusHeader(
                                balls: _state.balls,
                                look: widget.config.look,
                              ),
                            ),
                            const SizedBox(height: 28),
                            MatchStatusHeader(
                              headline: headline,
                              subtitle: roundLabel,
                              dimmed: finished,
                              align: TextAlign.start,
                            ),
                            const SizedBox(height: 28),
                            scoreboard,
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                timer,
                                pause,
                                const SizedBox(width: 8),
                                restart,
                              ],
                            ),
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

/// The contestants side by side, "A VS B (VS C ...)": big at the top of the
/// right panel on wide screens, [compact] above the arena on phones.
/// Knocked-out balls fade.
class _VersusHeader extends StatelessWidget {
  final List<SimulationBall> balls;
  final bool compact;

  /// Faces: each picture gets a small live smiley beside it (the arena shows only the smileys).
  final BallLook look;

  const _VersusHeader({
    required this.balls,
    this.compact = false,
    this.look = BallLook.pictures,
  });

  /// The smiley's diameter as a share of the picture's.
  static const double smileyScale = 0.55;

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final size = compact
        ? (balls.length <= 2 ? 40.0 : 32.0)
        : (balls.length <= 2 ? 96.0 : 64.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < balls.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.only(top: size / 2 - 10),
              child: Text(
                'VS',
                style: AppText.mono(
                  compact ? 12 : 16,
                  color: c.muted,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          Expanded(
            child: AnimatedOpacity(
              opacity: balls[i].isEliminated ? 0.3 : 1,
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  if (look == BallLook.faces)
                    // The picture with its smiley at its lower right, overlapping a little, same base line.
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircularBallPreview(ball: balls[i].config, size: size),
                        Positioned(
                          right: -size * smileyScale * 0.45,
                          bottom: 0,
                          child: CustomPaint(
                            size: Size.square(size * smileyScale),
                            painter: _SmileyPainter(balls[i], balls),
                          ),
                        ),
                      ],
                    )
                  else
                    CircularBallPreview(ball: balls[i].config, size: size),
                  SizedBox(height: compact ? 4 : 10),
                  Text(
                    balls[i].config.name,
                    maxLines: compact ? 1 : 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(
                      compact ? 12 : (balls.length <= 2 ? 16 : 13),
                      FontWeight.w700,
                      color: c.text,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A ball's live smiley (expression and eyes as in the arena), for the VS header.
class _SmileyPainter extends CustomPainter {
  _SmileyPainter(this.ball, this.balls);

  final SimulationBall ball;
  final List<SimulationBall> balls;

  @override
  void paint(Canvas canvas, Size size) => paintSmiley(
    canvas,
    ball,
    faceHealth(ball),
    balls,
    center: size.center(Offset.zero),
    radius: size.shortestSide / 2,
  );

  @override
  bool shouldRepaint(_SmileyPainter old) => true;
}

/// The red X over the eliminated ball while it flashes (same as the video).
class _LoserCrossPainter extends CustomPainter {
  _LoserCrossPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) => ReplayFramePainter.paintLoserCross(
    canvas,
    size.center(Offset.zero),
    size.shortestSide / 2,
    progress,
  );

  @override
  bool shouldRepaint(_LoserCrossPainter old) => old.progress != progress;
}
