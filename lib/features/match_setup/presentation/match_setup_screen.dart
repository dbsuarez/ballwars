import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../../ball_management/domain/ball_repository.dart';
import '../domain/match_config.dart';
import 'widgets/ball_selection_carousel.dart';

class MatchSetupScreen extends StatefulWidget {
  final BallRepository repository;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({
    super.key,
    required this.repository,
    required this.onStartBattle,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final Set<String> _selectedIds = {};
  double _speedMultiplier = 1.0;
  WinCondition _winCondition = WinCondition.domination;

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 4) {
        _selectedIds.add(id);
      }
    });
  }

  bool get _canStart => _selectedIds.length >= 2 && _selectedIds.length <= 4;

  void _start() {
    if (!_canStart) return;
    final allBalls = widget.repository.getAll();
    final contestants = allBalls.where((b) => _selectedIds.contains(b.id)).toList();
    widget.onStartBattle(MatchConfig(
      contestants: contestants,
      speedMultiplier: _speedMultiplier,
      winCondition: _winCondition,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final balls = widget.repository.getAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select 2-4 Balls'),
            const SizedBox(height: 8),
            BallSelectionCarousel(
              availableBalls: balls,
              selectedIds: _selectedIds,
              onToggle: _toggle,
            ),
            const SizedBox(height: 24),
            const Text('Speed'),
            Slider(
              value: _speedMultiplier,
              min: 0.5,
              max: 4.0,
              divisions: 3,
              label: '${_speedMultiplier}x',
              onChanged: (v) => setState(() => _speedMultiplier = v),
            ),
            const SizedBox(height: 16),
            const Text('Win Condition'),
            SegmentedButton<WinCondition>(
              segments: const [
                ButtonSegment(value: WinCondition.domination, label: Text('Domination')),
                ButtonSegment(value: WinCondition.timeAttack, label: Text('Time Attack')),
              ],
              selected: {_winCondition},
              onSelectionChanged: (s) => setState(() => _winCondition = s.first),
            ),
            const Spacer(),
            Center(
              child: NeonButton(
                label: 'START BATTLE',
                onPressed: _start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
