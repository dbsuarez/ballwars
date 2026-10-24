import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_canvas.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import 'app_settings_scope.dart';

/// Runs actual matches with local, admin-only scenario controls.
class PowerUpTestScreen extends StatefulWidget {
  const PowerUpTestScreen({super.key});

  @override
  State<PowerUpTestScreen> createState() => _PowerUpTestScreenState();
}

class _PowerUpTestScreenState extends State<PowerUpTestScreen>
    with SingleTickerProviderStateMixin {
  static const _balls = [
    CustomBall(
      id: 'test-a', name: 'Ball A',
      primaryColor: Color(0xFFFF5B4D), glowColor: Color(0xFFFFA38F),
    ),
    CustomBall(
      id: 'test-b', name: 'Ball B',
      primaryColor: Color(0xFF4D9DFF), glowColor: Color(0xFF7EDBFF),
    ),
  ];
  late final Ticker _ticker;
  Duration? _previous;
  bool _checking = false;
  bool? _allowed;
  MatchSimulationController? _match;
  bool _paused = true;
  bool _randomSpawns = false;
  bool _endless = false;
  double _speed = 1;
  MatchMode _mode = MatchMode.arsenal;
  String _layout = 'Separated';
  final _pinned = [false, false];
  final _items = [PowerUpKind.pistol, PowerUpKind.shield];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checking) {
      _checking = true;
      _checkAccess();
    }
  }

  Future<void> _checkAccess() async {
    bool allowed;
    try {
      allowed = await AppSettingsScope.maybeScope(context)
              ?.adminAuth?.isAdmin() ?? false;
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      if (allowed) _reset();
    });
  }

  void _reset() {
    if (_ticker.isActive) _ticker.stop();
    _match = MatchSimulationController(
      _balls,
      arenaRadius: 200,
      seed: 42,
      mode: _mode,
      tuning: AppSettingsScope.of(context).powerUps,
      lookAhead: false,
      slowMotionLines: 0,
      endlessBattle: _endless,
    );
    _match!.powerUps!.automaticSpawning = _randomSpawns;
    final balls = _match!.state.balls;
    final distance = _layout == 'Contact' ? balls.first.radius : 75.0;
    if (_layout != 'Natural') {
      balls[0].position = Offset(-distance, 0);
      balls[1].position = Offset(distance, 0);
      balls[0].velocity = const Offset(100, 0);
      balls[1].velocity = const Offset(-100, 0);
    }
    for (var i = 0; i < balls.length; i++) {
      _match!.setTestBallPinned(balls[i], _pinned[i]);
    }
    _paused = true;
    _previous = null;
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (_paused || previous == null || _match == null) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    // Ignore background/resume gaps instead of skipping ahead in the fight.
    if (dt <= 0 || dt > 0.25) return;
    setState(() => _match!.tick(dt * _speed));
    if (_match!.state.status == MatchStatus.finished) _ticker.stop();
  }

  void _give(int index) {
    final match = _match!;
    final ball = match.state.balls[index];
    final kind = _items[index];
    if (kind.isTrap) {
      match.powerUps!.spawnTestItem(kind);
    } else {
      match.powerUps!.pickUp(ball, FieldPowerUp(
        kind: kind, position: ball.position, spawnStep: match.stepCount,
      ));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    if (_allowed != true || match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Power-up Tests')),
        body: Center(child: _allowed == null
            ? const CircularProgressIndicator()
            : const Text('Admin access required.')),
      );
    }
    final state = match.state;
    final finished = state.status == MatchStatus.finished;
    return Scaffold(
      appBar: AppBar(title: const Text('Power-up Tests')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Live simulation using your saved power-up numbers. '
                    'Give items, then press Play. Changes here affect only this test.'),
                const SizedBox(height: 12),
                Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: RepaintBoundary(child: ArenaCanvas(
                    state: state,
                    arenaRadius: match.arenaRadius,
                    rimAngle: 0,
                    look: BallLook.faces,
                  )),
                )),
                Text(finished
                    ? 'Winner: ${state.balls.firstWhere((b) => b.config.id == state.winnerId).config.name}'
                    : '${_paused ? "Paused" : "Running"} - ${(state.step / 60).toStringAsFixed(1)} s'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: finished ? null : () => setState(() {
                      _paused = !_paused;
                      _previous = null;
                      if (_paused) {
                        _ticker.stop();
                      } else {
                        _ticker.start();
                      }
                    }),
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    label: Text(_paused ? 'Play' : 'Pause'),
                  ),
                  OutlinedButton(
                    onPressed: !_paused || finished ? null : () => setState(() {
                      match.tick(MatchSimulationController.fixedTimestep /
                          match.playbackSpeedUp);
                    }),
                    child: const Text('Step frame'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(_reset),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset fight'),
                  ),
                  DropdownButton<double>(
                    value: _speed,
                    items: [for (final speed in [0.25, 0.5, 1.0, 2.0])
                      DropdownMenuItem(value: speed, child: Text('${speed}x'))],
                    onChanged: (value) => setState(() => _speed = value!),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('Scenario changes reset and pause the fight.'),
                Wrap(spacing: 20, children: [
                  DropdownButton<MatchMode>(
                    value: _mode,
                    items: const [
                      DropdownMenuItem(value: MatchMode.arsenal, child: Text('Arsenal')),
                      DropdownMenuItem(value: MatchMode.allOut, child: Text('All-Out')),
                    ],
                    onChanged: (value) => setState(() { _mode = value!; _reset(); }),
                  ),
                  DropdownButton<String>(
                    value: _layout,
                    items: [for (final layout in ['Separated', 'Contact', 'Natural'])
                      DropdownMenuItem(value: layout, child: Text(layout))],
                    onChanged: (value) => setState(() { _layout = value!; _reset(); }),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Random item spawns'),
                  value: _randomSpawns,
                  onChanged: (value) => setState(() {
                    _randomSpawns = value;
                    match.powerUps!.automaticSpawning = value;
                  }),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Endless fight'),
                  subtitle: const Text('Respawn eliminated balls to keep testing.'),
                  value: _endless,
                  onChanged: (value) => setState(() { _endless = value; _reset(); }),
                ),
                const Text('Freeze locks position while attacks, damage and timers continue. '
                    'It also prevents movement from hooks, portals and knockback. '
                    'Traps are placed near the rim using normal spawn rules.'),
                for (var i = 0; i < state.balls.length; i++)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('${state.balls[i].config.name} - '
                          '${_mode == MatchMode.arsenal ? "${state.balls[i].life.toStringAsFixed(0)} life" : "${state.balls[i].fanLines.length} threads"}'
                          '${state.balls[i].isEliminated ? " - eliminated" : ""}'),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Freeze Ball ${i == 0 ? "A" : "B"} in place'),
                        value: _pinned[i],
                        onChanged: (value) => setState(() {
                          _pinned[i] = value;
                          match.setTestBallPinned(state.balls[i], value);
                        }),
                      ),
                      DropdownButton<PowerUpKind>(
                        isExpanded: true,
                        value: _items[i],
                        items: [for (final kind in PowerUpKind.values)
                          DropdownMenuItem(value: kind, child: Text(kind.label))],
                        onChanged: (value) => setState(() => _items[i] = value!),
                      ),
                      FilledButton.tonal(
                        onPressed: finished || state.balls[i].isEliminated
                            ? null : () => setState(() => _give(i)),
                        child: Text(_items[i].isTrap ? 'Place ${_items[i].label} trap'
                            : 'Give ${_items[i].label} to ${state.balls[i].config.name}'),
                      ),
                    ]),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
