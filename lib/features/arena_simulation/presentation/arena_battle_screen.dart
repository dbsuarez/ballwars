import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../application/match_simulation_controller.dart';
import '../domain/simulation_state.dart';
import '../../match_setup/domain/match_config.dart';
import 'arena_canvas.dart';
import 'scoreboard_overlay.dart';
import 'widgets/match_status_header.dart';
import 'winner_modal.dart';

class ArenaBattleScreen extends StatefulWidget {
  final MatchConfig config;
  final int? seed;

  const ArenaBattleScreen({super.key, required this.config, this.seed});

  @override
  State<ArenaBattleScreen> createState() => _ArenaBattleScreenState();
}

class _ArenaBattleScreenState extends State<ArenaBattleScreen>
    with SingleTickerProviderStateMixin {
  static const double _arenaRadius = 260.0;

  late MatchSimulationController _controller;
  late Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _rimAngle = 0.0;
  late SimulationState _state;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initMatch();
    _ticker = createTicker(_onTick)..start();
  }

  void _initMatch() {
    _controller = MatchSimulationController(
      widget.config.contestants,
      arenaRadius: _arenaRadius,
      seed: widget.seed,
    );
    _state = _controller.state;
    _rimAngle = 0.0;
    _lastElapsed = Duration.zero;
    _controller.preloadImages().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || _isPaused) return;

    _controller.tick(dt * widget.config.speedMultiplier);
    // Sector rim attachment points stay fixed (rimAngle is not incremented) —
    // only the balls move; the rim itself does not rotate.

    setState(() {
      _state = _controller.state;
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  void _replay() {
    setState(_initMatch);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFinished = _state.winnerId != null;
    final winnerBall = isFinished
        ? _state.balls.firstWhere((b) => b.config.id == _state.winnerId).config
        : null;

    return Scaffold(
      appBar: AppBar(
        title: MatchStatusHeader(isSlowMotion: _state.status == MatchStatus.slowMotion),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _isPaused ? 'Play' : 'Pause',
            onPressed: _togglePause,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPortrait = constraints.maxHeight >= constraints.maxWidth;
            final arena = ArenaCanvas(state: _state, arenaRadius: _arenaRadius, rimAngle: _rimAngle);
            final scoreboard = Padding(
              padding: const EdgeInsets.all(16),
              child: ScoreboardOverlay(balls: _state.balls),
            );

            final content = isPortrait
                ? Column(children: [Expanded(child: arena), scoreboard])
                : Row(children: [
                    Expanded(child: arena),
                    SizedBox(width: 240, child: scoreboard),
                  ]);

            return Stack(
              children: [
                content,
                if (isFinished && winnerBall != null)
                  Positioned.fill(
                    child: WinnerModal(
                      winner: winnerBall,
                      onReplay: _replay,
                      onExit: () => Navigator.of(context).maybePop(),
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
