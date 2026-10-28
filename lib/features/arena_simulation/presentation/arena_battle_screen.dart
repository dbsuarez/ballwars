import '../../../core/widgets/screen_awake.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../../settings/domain/app_settings.dart';
import '../application/match_simulation_controller.dart';
import '../domain/simulation_ball.dart';
import '../domain/simulation_state.dart';
import '../domain/power_up.dart';
import '../../match_setup/domain/match_config.dart';
import 'power_up_sprites.dart';
import 'ball_face_expression.dart';
import 'arena_canvas.dart';
import 'scoreboard_overlay.dart';
import 'widgets/match_status_header.dart';
import 'winner_modal.dart';
import 'harpoon_cinematic.dart';
import 'finisher_profile.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_management/data/local_ball_repository.dart';
import '../../replay_export/data/video_encoder.dart';
import '../../replay_export/data/video_export_backend.dart';
import '../../replay_export/domain/replay_link.dart';
import '../../replay_export/data/saved_replay_store.dart';
import '../../replay_export/presentation/export_video_dialog.dart';
import '../../replay_export/presentation/replay_frame_painter.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/audio/audio_channel_button.dart';
import '../../settings/data/effects_prefs.dart';

class ArenaBattleScreen extends StatefulWidget {
  final MatchConfig config;
  final int? seed;

  /// Unstuck nudges of a replayed match (steps), repeated in its first round.
  final List<int> nudgeSteps;

  /// End battle step of a replayed endless match, repeated in its first round.
  final int? endStep;

  const ArenaBattleScreen({
    super.key,
    required this.config,
    this.seed,
    this.nudgeSteps = const [],
    this.endStep,
  });

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
  bool _foreground = true;

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
  bool _showHarpoonCinematic = false;
  bool _finishersOn = true;

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
    _finishersOn = widget.config.finishersEnabled ?? true;
    if (widget.config.finishersEnabled == null) {
      EffectsPrefs.finishersOn().then((on) {
        if (mounted) setState(() => _finishersOn = on);
      });
    }
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
  final Map<String, int> _roundLosses = {};
  bool _roundCounted = false;

  bool get _seriesOver =>
      _roundWins.values.any((w) => w >= widget.config.winsNeeded);

  bool _started = false;
  double _startCountdown = 3;
  int _countdownBeat = 3;

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

  /// True while the current round is a replay (the Replay button, or a match opened from a link or
  /// the saved replays list, in its first round): there is nothing new to save. Play again, New match
  /// and the next round of a series start new matches and clear it.
  bool _watchingReplay = false;

  /// Starts a match. [replaySeed] re-runs a finished match exactly (Replay); it isn't counted again.
  void _initMatch({
    int? replaySeed,
    List<int> replayNudges = const [],
    int? replayEndStep,
  }) {
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
      customSkillIds: widget.config.customSkills,
      tuning: widget.config.tuning,
      skillLibrary: widget.config.skillLibrary,
      dualWield: widget.config.dualWield,
      endlessBattle: widget.config.endlessBattle,
      mayhem: widget.config.mayhem,
      mayhemSeconds: widget.config.mayhemSeconds,
      shrinkingArena: widget.config.shrinkingArena,
      minimumArenaScale: widget.config.minimumArenaScale,
      bloodColor: widget.config.bloodColor,
      arenaDecoration: widget.config.arenaDecoration,
      automaticSpeedUp: widget.config.automaticSpeedUp,
      randomizedHairstyles: widget.config.randomizedHairstyles,
      // A replay repeats its Unstuck nudges: the Replay button's own match, or a replay link's first round.
      nudgeSteps: replaySeed != null
          ? replayNudges
          : (_seedBase != null && _round == 1 ? widget.nudgeSteps : const []),
      // And its End battle step, the same way.
      endAfterKnockoutStep: replaySeed != null
          ? replayEndStep
          : (_seedBase != null && _round == 1 ? widget.endStep : null),
    );
    _roundCounted = replaySeed != null;
    _watchingReplay = replaySeed != null || (_seedBase != null && _round == 1);
    _startCountdown = 3;
    _countdownBeat = 3;
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
    _skipNextDelta = true;
    _showDissolve = false;
    _loserBall = null;
    _winnerBall = null;
    _dissolveComplete = false;
    _showHarpoonCinematic = false;
    _endPending = false;
    _heardWallHits = 0;
    _heardBallHits = 0;
    _heardPowerUps = (0, 0, 0, 0, 0, 0);
    _heardInteractions.clear();
    _heardCuts = 0;
    _heardKnockouts = 0;
    _heardGatling = 0;
    _audio.resetEffects();
    _audio.interaction('countdown');
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

    var dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || _isPaused || !_foreground) return;

    if (_startCountdown > 0) {
      final before = _startCountdown;
      _startCountdown = math.max(0, _startCountdown - dt);
      final beat = _startCountdown.ceil();
      if (beat > 0 && beat < _countdownBeat) {
        _countdownBeat = beat;
        _audio.interaction('countdown');
      }
      _frame.value++;
      if (_startCountdown > 0) return;
      _audio.interaction('countdown-go');
      _audio.startMusic();
      dt = math.max(0, dt - before);
      if (dt == 0) return;
    }

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
      if (widget.config.mayhem) _audio.whistle();
      final generation = _matchGeneration;
      bool current() => mounted && generation == _matchGeneration;
      Future.delayed(_endPause, () {
        if (!current()) return;
        setState(() {
          _winnerBall = _state.balls
              .firstWhere((b) => b.config.id == _state.winnerId)
              .config;
          // Mayhem supplies last place by final KO/life ranking; other modes use the last knockout.
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
          final hasFinisher = _finishersOn && _controller.winningMove != null;
          if (!hasFinisher) _audio.win();
          setState(() {
            _dissolveComplete = true;
            _showHarpoonCinematic = hasFinisher;
            if (!_roundCounted && _winnerBall != null) {
              _roundCounted = true;
              _roundWins.update(
                _winnerBall!.id,
                (w) => w + 1,
                ifAbsent: () => 1,
              );
              for (final contestant in widget.config.contestants) {
                if (contestant.id == _winnerBall!.id) continue;
                _roundLosses.update(
                  contestant.id,
                  (losses) => losses + 1,
                  ifAbsent: () => 1,
                );
              }
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
  final Map<String, int> _heardInteractions = {};
  final Map<String, int> _heardSkillSounds = {};
  int _heardCuts = 0;
  int _heardKnockouts = 0;

  void _playPowerUpSounds() {
    final soundController = _controller;
    if (soundController.threadCuts < _heardCuts ||
        soundController.knockouts < _heardKnockouts) {
      _heardInteractions.clear();
    }
    if (soundController.threadCuts > _heardCuts) _audio.interaction('cut');
    if (soundController.knockouts > _heardKnockouts) _audio.interaction('out');
    _heardCuts = soundController.threadCuts;
    _heardKnockouts = soundController.knockouts;
    for (final event
        in soundController.powerUps?.interactionSounds.entries ??
            const <MapEntry<String, int>>[]) {
      if (event.value > (_heardInteractions[event.key] ?? 0)) {
        _audio.interaction(event.key);
      }
      _heardInteractions[event.key] = event.value;
    }
    for (final event
        in soundController.powerUps?.skillSounds.entries ??
            const <MapEntry<String, int>>[]) {
      if (event.value > (_heardSkillSounds[event.key] ?? 0)) {
        _audio.skillCue(event.key);
      }
      _heardSkillSounds[event.key] = event.value;
    }

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

  void _playFinisherLaunch() {
    final profile = FinisherProfile.forMove(
      _controller.winningMove ?? 'Collision',
    );
    switch (profile.style) {
      case FinisherStyle.projectile:
        _audio.shot();
      case FinisherStyle.barrage:
        profile.move == 'Gatling' ? _audio.gatling() : _audio.shotgun();
      case FinisherStyle.melee:
        _audio.slash();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        _audio.bomb();
      case FinisherStyle.hook:
        _audio.shotgun();
      case FinisherStyle.aura:
        _audio.shield();
      case FinisherStyle.warp:
        _audio.pickup();
    }
  }

  void _playFinisherImpact() {
    final profile = FinisherProfile.forMove(
      _controller.winningMove ?? 'Collision',
    );
    switch (profile.style) {
      case FinisherStyle.projectile:
      case FinisherStyle.barrage:
      case FinisherStyle.hook:
        _audio.hit();
      case FinisherStyle.melee:
        _audio.collide();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        _audio.bomb();
      case FinisherStyle.aura:
        _audio.shield();
      case FinisherStyle.warp:
        _audio.pickup();
    }
  }

  /// Back from the background (phone unlocked): the next frame is not
  /// counted, so there's no time jump. (GameAudio pauses and resumes music.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _skipNextDelta = true;
  }

  /// Copies a link that replays this exact match in the web app: a short
  /// `?r=<code>` link when the server is reachable, else the long one.
  Future<void> _copyReplayLink() async {
    final long = _replayUriOrExplain();
    if (long == null) return;
    Uri link = long;
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

  Uri _replayUri() => ReplayLink(
    effectRenderMode: widget.config.effectRenderMode,
    seed: _controller.seed,
    nudgeSteps: _controller.nudgeSteps,
    endStep: _controller.endStep,
    speedMultiplier: widget.config.speedMultiplier,
    automaticSpeedUp: widget.config.automaticSpeedUp,
    showEffects: _showEffects,
    ballGlowWidth: widget.config.ballGlowWidth,
    bloodColor: widget.config.bloodColor,
    randomizedHairstyles: widget.config.randomizedHairstyles,
    contestants: widget.config.contestants,
    ballSize: widget.config.ballSize,
    mode: widget.config.mode,
    question: widget.config.question,
    look: widget.config.look,
    powerUps: widget.config.powerUps,
    customSkills: widget.config.customSkills,
    tuning: widget.config.tuning,
    dualWield: widget.config.dualWield,
    endlessBattle: widget.config.endlessBattle,
    mayhem: widget.config.mayhem,
    mayhemSeconds: widget.config.mayhemSeconds,
    shrinkingArena: widget.config.shrinkingArena,
    minimumArenaScale: widget.config.minimumArenaScale,
    arenaDecoration: widget.config.arenaDecoration,
    skillLibrary: widget.config.skillLibrary,
  ).toUri(presetIds: {for (final b in LocalBallRepository.presets) b.id});

  /// [_replayUri], or null after telling the user why there is none: the custom skill snapshot is
  /// over `SkillLibrary.maxReplayCharacters`.
  Uri? _replayUriOrExplain() {
    try {
      return _replayUri();
    } on FormatException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Too many custom skills to share this replay'),
        ),
      );
      return null;
    }
  }

  Future<void> _saveReplay() async {
    final uri = _replayUriOrExplain();
    if (uri == null) return;
    await SavedReplayStore.add(
      uri,
      contestantNames: widget.config.contestants.map((ball) => ball.name),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Replay saved on this device.')),
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
      _roundLosses.clear();
      _initMatch();
    });
  }

  /// Unstuck: every ball still in play gets a push in a random direction at the next step. The step is
  /// recorded with the match, so replays and videos nudge at the same moment.
  void _unstuck() {
    _audio.click();
    _controller.requestNudge();
  }

  /// End battle (endless, not Mayhem): the match ends at the next knockout with the usual finish. The
  /// step is recorded with the match, so replays and videos end at the same knockout.
  void _endBattle() {
    _audio.click();
    setState(_controller.requestEndAfterKnockout);
  }

  /// Width the bottom-right audio buttons take (three 44 px buttons, two gaps, a margin).
  static const double _audioButtonsWidth = 148;

  /// Room the bottom-left row needs for Unstuck plus a labeled End battle; narrower, End battle is
  /// an icon with its label in the tooltip.
  static const double _endBattleLabelWidth = 300;

  /// End battle: enabled until pressed. "Ending after next KO" once the request is in force (a replay
  /// with a recorded end step shows it only from that step, and can't be ended by hand).
  Widget _endBattleButton({required bool compact}) => ListenableBuilder(
    listenable: _frame,
    builder: (context, _) {
      final endStep = _controller.endStep;
      final ending = endStep == null
          ? _controller.endRequested
          : _controller.stepCount >= endStep;
      final label = ending ? 'Ending after next KO' : 'End battle';
      final onPressed = _state.winnerId != null || _controller.endRequested
          ? null
          : _endBattle;
      final style = OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(40, 36),
      );
      return Tooltip(
        message: compact ? label : 'End the battle after the next knockout',
        child: compact
            ? OutlinedButton(
                key: const ValueKey('arena-end-battle'),
                onPressed: onPressed,
                style: style,
                child: Icon(
                  ending ? Icons.hourglass_bottom_rounded : Icons.flag_rounded,
                  size: 18,
                ),
              )
            : OutlinedButton.icon(
                key: const ValueKey('arena-end-battle'),
                onPressed: onPressed,
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(label),
                style: style,
              ),
      );
    },
  );

  /// Replay: watch the match that just ended again, exactly as it played (same seed; the round isn't
  /// counted twice).
  void _replay() {
    _audio.click();
    final seed = _controller.seed;
    final nudges = _controller.nudgeSteps;
    final endStep = _controller.endStep;
    setState(() {
      _isPaused = false;
      _initMatch(
        replaySeed: seed,
        replayNudges: nudges,
        replayEndStep: endStep,
      );
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

  Offset _screenShakeOffset() {
    if (!_showEffects || _state.powerUps == null) return Offset.zero;
    var strength = 0.0;
    for (final explosion in _state.powerUps!.explosions) {
      final life =
          1 - explosion.age / PowerUpTuning.explosionShowSteps.toDouble();
      if (life > strength) strength = life;
    }
    for (final impact in _state.powerUps!.weaponImpacts) {
      final life = 1 - impact.age / 12.0;
      final weighted = life * impact.strength;
      if (weighted > strength) strength = weighted;
    }
    if (strength <= 0) return Offset.zero;
    final magnitude = 7.0 * strength * strength;
    return Offset(
      math.sin(_state.step * 2.31) * magnitude,
      math.cos(_state.step * 2.87) * magnitude * 0.72,
    );
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
      key: const ValueKey('restart-match'),
      onPressed: _playAgain,
      child: Text(
        widget.config.mayhem
            ? 'Mayhem match'
            : '${widget.config.mode.label} match',
      ),
    );
    final pause = IconButton(
      icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      tooltip: _isPaused ? 'Play' : 'Pause',
      onPressed: _togglePause,
    );
    final scoreboard = ListenableBuilder(
      listenable: _frame,
      builder: (context, _) => ScoreboardOverlay(
        artworkTint: (ball, kind) =>
            _state.powerUps?.artworkTint(kind, ball: ball) ?? 0xFFFFFFFF,
        itemRarity: (ball, kind) =>
            _state.powerUps?.itemRarity(kind, ball: ball) ??
            widget.config.tuning.rarityOf(kind),
        tuning: widget.config.tuning,
        mode: widget.config.mode,
        compact:
            MediaQuery.sizeOf(context).height >=
            MediaQuery.sizeOf(context).width,
        balls: _state.balls,
        wins: widget.config.winsNeeded > 1 ? _roundWins : null,
        eliminations: widget.config.endlessBattle
            ? _controller.eliminations
            : null,
        deaths: widget.config.endlessBattle ? _controller.deaths : null,
      ),
    );

    return ScreenAwake(
      enabled: !_isPaused && _foreground && !finished,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isPortrait = constraints.maxHeight >= constraints.maxWidth;
              // Side margins keep the arena off the screen edges on phones;
              // the slow-motion badge sits at the top of the arena.
              final arena = ListenableBuilder(
                listenable: _frame,
                builder: (context, _) => Transform.translate(
                  offset: _screenShakeOffset().scale(0.2, 0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 0,
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: ArenaCanvas(
                              state: _state,
                              arenaRadius: _controller.arenaRadius,
                              worldRadius: _arenaRadius,
                              rimInset: 0,
                              rimAngle: _rimAngle,
                              showEffects: _showEffects,
                              showBallGlow: AppSettingsScope.of(
                                context,
                              ).ballGlowEnabled,
                              ballGlowWidth: widget.config.ballGlowWidth,
                              arenaTitle: AppSettingsScope.of(
                                context,
                              ).arenaTitle,
                              arenaSubtitle: AppSettingsScope.of(
                                context,
                              ).arenaSubtitle,
                              arenaDecoration: widget.config.arenaDecoration,
                              wallSparkSize: widget.config.wallSparkSize,
                              repaint: _frame,
                              look: widget.config.look,
                              handsOnPictures: widget.config.handsOnPictures,
                              showHpBars: widget.config.showHpBars,
                              whitePickupBackgrounds:
                                  widget.config.whitePickupBackgrounds,
                              projectileRenderMode:
                                  widget.config.effectRenderMode ??
                                  AppSettingsScope.of(
                                    context,
                                  ).projectileRenderMode,
                              explosionRenderMode:
                                  widget.config.effectRenderMode ??
                                  AppSettingsScope.of(
                                    context,
                                  ).explosionRenderMode,
                              freezeRenderMode:
                                  widget.config.effectRenderMode ??
                                  AppSettingsScope.of(context).freezeRenderMode,
                            ),
                          ),
                        ),
                        if (_startCountdown > 0)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: c.text, width: 2),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 26,
                                      vertical: 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'ROUND START',
                                          style: AppText.ui(
                                            15,
                                            FontWeight.w900,
                                            color: c.text,
                                          ),
                                        ),
                                        Text(
                                          '${_startCountdown.ceil()}',
                                          key: const ValueKey(
                                            'round-start-countdown',
                                          ),
                                          style: AppText.mono(
                                            44,
                                            color: c.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          // Leaves room for the three audio buttons at the bottom right.
                          right: _audioButtonsWidth,
                          child: LayoutBuilder(
                            builder: (context, box) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message:
                                      'Unstuck: push every ball in a random direction',
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('arena-unstuck'),
                                    onPressed: finished ? null : _unstuck,
                                    icon: const Icon(
                                      Icons.open_with_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Unstuck'),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.config.endlessBattle &&
                                    !widget.config.mayhem) ...[
                                  const SizedBox(width: 8),
                                  _endBattleButton(
                                    compact:
                                        box.maxWidth < _endBattleLabelWidth,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: const Row(
                            children: [
                              AudioChannelButton(
                                key: ValueKey('arena-bgm-control'),
                                channel: AudioChannel.bgm,
                              ),
                              SizedBox(width: 4),
                              AudioChannelButton(
                                key: ValueKey('arena-sfx-control'),
                                channel: AudioChannel.sfx,
                              ),
                              SizedBox(width: 4),
                              AudioChannelButton(
                                key: ValueKey('arena-ux-control'),
                                channel: AudioChannel.ux,
                              ),
                            ],
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
                        if (widget.config.shrinkingArena)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.68),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    'ARENA ${(_controller.arenaRadius / _controller.initialArenaRadius * 100).round()}%',
                                    key: const ValueKey('arena-shrink-percent'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );

              final overlays = <Widget>[
                // The runner-up shown big, then the winner card.
                if (_showDissolve && !_dissolveComplete && _loserBall != null)
                  _buildDissolveAnimation(),
                if (_showHarpoonCinematic &&
                    _winnerBall != null &&
                    _loserBall != null)
                  Positioned.fill(
                    child: HarpoonCinematic(
                      winner: _winnerBall!,
                      loser: _loserBall!,
                      move: _controller.winningMove ?? 'Collision',
                      effectSprites:
                          _controller.skillLibrary
                              .all(_controller.tuning)
                              .where(
                                (skill) =>
                                    skill.name == _controller.winningMove,
                              )
                              .firstOrNull
                              ?.usesSpriteEffects(
                                globalSprite:
                                    (widget.config.effectRenderMode ??
                                        AppSettingsScope.of(
                                          context,
                                        ).explosionRenderMode) ==
                                    EffectRenderMode.sprite,
                              ) ??
                          true,
                      artworkTint:
                          _controller.skillLibrary
                              .all(_controller.tuning)
                              .where(
                                (skill) =>
                                    skill.name == _controller.winningMove,
                              )
                              .firstOrNull
                              ?.spriteTint ??
                          0xFFFFFFFF,
                      visualMove: _controller.skillLibrary
                          .all(_controller.tuning)
                          .where(
                            (skill) => skill.name == _controller.winningMove,
                          )
                          .firstOrNull
                          ?.displayKind
                          .label,
                      onHookFired: _playFinisherLaunch,
                      onImpact: _playFinisherImpact,
                      onFinished: () {
                        if (!mounted) return;
                        _audio.win();
                        setState(() => _showHarpoonCinematic = false);
                      },
                    ),
                  ),
                if (_dissolveComplete &&
                    !_showHarpoonCinematic &&
                    _winnerBall != null)
                  Positioned.fill(
                    child: WinnerModal(
                      winner: _winnerBall!,
                      mayhemTally: [
                        for (final ball in _state.balls)
                          (
                            ball.config,
                            _controller.eliminations[ball.config.id] ?? 0,
                            _controller.deaths[ball.config.id] ?? 0,
                            widget.config.mode == MatchMode.arsenal
                                ? ball.life
                                : ball.fanLines.length.toDouble(),
                          ),
                      ],
                      tallyIsHealth: widget.config.mode == MatchMode.arsenal,
                      question: widget.config.question,
                      durationSeconds: _controller.elapsedSeconds,
                      winningMove: _controller.winningMove,
                      onSaveVideo: _videoExport == null
                          ? null
                          : () {
                              _audio.click();
                              ExportVideoDialog.show(
                                effectRenderMode:
                                    widget.config.effectRenderMode ??
                                    AppSettingsScope.of(
                                      context,
                                    ).explosionRenderMode,
                                context,
                                contestants: widget.config.contestants,
                                seed: _controller.seed,
                                nudgeSteps: _controller.nudgeSteps,
                                endStep: _controller.endStep,
                                arenaRadius: _arenaRadius,
                                speedMultiplier: widget.config.speedMultiplier,
                                automaticSpeedUp:
                                    widget.config.automaticSpeedUp,
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
                                showHpBars: widget.config.showHpBars,
                                powerUps: widget.config.powerUps,
                                customSkills: widget.config.customSkills,
                                tuning: widget.config.tuning,
                                skillLibrary: widget.config.skillLibrary,
                                endlessBattle: widget.config.endlessBattle,
                                dualWield: widget.config.dualWield,
                                mayhem: widget.config.mayhem,
                                mayhemSeconds: widget.config.mayhemSeconds,
                                shrinkingArena: widget.config.shrinkingArena,
                                minimumArenaScale:
                                    widget.config.minimumArenaScale,
                                finishersEnabled: _finishersOn,
                                randomizedHairstyles:
                                    widget.config.randomizedHairstyles,
                                arenaDecoration: widget.config.arenaDecoration,
                                headline: headline,
                                colors: c,
                                ballGlowEnabled: AppSettingsScope.of(
                                  context,
                                ).ballGlowEnabled,
                                ballGlowWidth: widget.config.ballGlowWidth,
                                bloodColor: widget.config.bloodColor,
                                arenaTitle: AppSettingsScope.of(
                                  context,
                                ).arenaTitle,
                                arenaSubtitle: AppSettingsScope.of(
                                  context,
                                ).arenaSubtitle,
                                backend: _videoExport,
                              );
                            },
                      onShareLink: () {
                        _audio.click();
                        _copyReplayLink();
                      },
                      onSaveReplay: _watchingReplay
                          ? null
                          : () {
                              _audio.click();
                              _saveReplay();
                            },
                      onReplay: _replay,
                      onReplayFinisher:
                          _finishersOn &&
                              _controller.winningMove != null &&
                              _loserBall != null
                          ? () {
                              _audio.click();
                              setState(() => _showHarpoonCinematic = true);
                            }
                          : null,
                      onPlayAgain: _playAgain,
                      round: widget.config.winsNeeded > 1 ? _round : null,
                      seriesOver: _seriesOver,
                      onNextRound: _seriesOver ? null : _nextRound,
                      score: widget.config.winsNeeded > 1
                          ? [
                              for (final b in widget.config.contestants)
                                (
                                  ball: b,
                                  wins: _roundWins[b.id] ?? 0,
                                  losses: _roundLosses[b.id] ?? 0,
                                  hp: _state.balls
                                      .firstWhere(
                                        (stateBall) =>
                                            stateBall.config.id == b.id,
                                      )
                                      .life,
                                ),
                            ]
                          : null,
                      onExit: () {
                        _audio.click();
                        Navigator.of(context).maybePop();
                      },
                      showEffects: _showEffects,
                      onSlowAnswer: _showEffects && _askSlow
                          ? _answerSlow
                          : null,
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
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          child: scoreboard,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final ballSize = math.min(size, constraints.maxWidth * 0.72);
                return AnimatedOpacity(
                  opacity: balls[i].isEliminated ? 0.3 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    children: [
                      if (look == BallLook.faces)
                        // The picture with its smiley at its lower right, overlapping a little, same base line.
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircularBallPreview(
                              ball: balls[i].config,
                              size: ballSize,
                            ),
                            Positioned(
                              right: -ballSize * smileyScale * 0.45,
                              bottom: 0,
                              child: CustomPaint(
                                size: Size.square(ballSize * smileyScale),
                                painter: _SmileyPainter(balls[i], balls),
                              ),
                            ),
                          ],
                        )
                      else
                        CircularBallPreview(
                          ball: balls[i].config,
                          size: ballSize,
                        ),
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
                );
              },
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
