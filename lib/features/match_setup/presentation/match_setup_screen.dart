import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/widgets/neon_button.dart';
import '../../ball_management/domain/ball_repository.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_packs/data/ball_pack_repository.dart';
import '../../ball_packs/domain/ball_pack.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../domain/match_config.dart';

/// Pick 2-4 balls from your own balls or the built-in packs (Streaming,
/// Countries, ...), mixing categories freely, then start the battle.
class MatchSetupScreen extends StatefulWidget {
  final BallRepository repository;

  /// Built-in packs; null hides them (e.g. in tests or offline builds).
  final BallPackRepository? packRepository;

  /// The user's own groups (My Groups); null hides them.
  final CustomGroupRepository? customGroups;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({
    super.key,
    required this.repository,
    this.packRepository,
    this.customGroups,
    required this.onStartBattle,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  static const String _myBalls = 'mine';
  static const int _maxBalls = 4;
  static const int _searchFrom = 20;

  // Insertion-ordered: contestants keep the order they were picked in.
  final Map<String, CustomBall> _selected = {};
  final TextEditingController _search = TextEditingController();
  final math.Random _random = math.Random();
  double _speedMultiplier = 1.0;
  String _category = _myBalls;
  List<BallPack> _packs = const [];
  // The user's groups, shown as categories after "My Balls".
  List<BallPack> _groups = const [];
  bool _packsLoading = false;
  bool _packsFailed = false;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPacks() async {
    _loadGroups();
    final repo = widget.packRepository;
    if (repo == null) return;
    setState(() {
      _packsLoading = true;
      _packsFailed = false;
    });
    try {
      final packs = await repo.load();
      if (mounted) setState(() => _packs = packs);
    } catch (_) {
      if (mounted) setState(() => _packsFailed = true);
    } finally {
      if (mounted) setState(() => _packsLoading = false);
    }
  }

  /// Groups that fail to load (offline, not set up) just don't show.
  Future<void> _loadGroups() async {
    final repo = widget.customGroups;
    if (repo == null) return;
    try {
      final groups = await repo.myGroups();
      if (!mounted) return;
      setState(() => _groups = [
            for (final g in groups)
              if (g.balls.isNotEmpty) BallPack(id: 'group:${g.id}', name: g.name, balls: g.balls),
          ]);
    } catch (_) {}
  }

  List<CustomBall> get _categoryBalls => _category == _myBalls
      ? widget.repository.getAll()
      : [..._groups, ..._packs]
          .firstWhere((p) => p.id == _category, orElse: () => const BallPack(id: '', name: '', balls: []))
          .balls;

  List<CustomBall> get _visibleBalls {
    final query = _search.text.trim().toLowerCase();
    final balls = _categoryBalls;
    return query.isEmpty ? balls : balls.where((b) => b.name.toLowerCase().contains(query)).toList();
  }

  void _toggle(CustomBall ball) {
    setState(() {
      if (_selected.remove(ball.id) == null && _selected.length < _maxBalls) {
        _selected[ball.id] = ball;
      }
    });
  }

  void _randomMatchup() {
    final pool = [..._categoryBalls]..shuffle(_random);
    if (pool.length < 2) return;
    setState(() {
      _selected
        ..clear()
        ..addEntries(pool.take(2).map((b) => MapEntry(b.id, b)));
    });
  }

  bool get _canStart => _selected.length >= 2 && _selected.length <= _maxBalls;

  void _start() {
    if (!_canStart) return;
    widget.onStartBattle(MatchConfig(
      contestants: _selected.values.toList(),
      speedMultiplier: _speedMultiplier,
    ));
  }

  void _selectCategory(String id) {
    setState(() {
      _category = id;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final balls = _visibleBalls;
    final showSearch = _categoryBalls.length > _searchFrom;

    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Select 2-4 Balls'),
              const SizedBox(height: 8),
              _categoryBar(),
              if (showSearch) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search',
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(child: _ballGrid(balls)),
              const SizedBox(height: 8),
              _selectionBar(),
              Row(
                children: [
                  const Text('Speed'),
                  Expanded(
                    child: Slider(
                      value: _speedMultiplier,
                      min: 0.5,
                      max: 4.0,
                      divisions: 3,
                      label: '${_speedMultiplier}x',
                      onChanged: (v) => setState(() => _speedMultiplier = v),
                    ),
                  ),
                ],
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _categoryBalls.length >= 2 ? _randomMatchup : null,
                    icon: const Icon(Icons.casino),
                    label: const Text('RANDOM MATCHUP'),
                  ),
                  NeonButton(label: 'START BATTLE', onPressed: _start),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _categoryChip(_myBalls, 'My Balls'),
          for (final group in _groups) _categoryChip(group.id, group.name),
          for (final pack in _packs) _categoryChip(pack.id, pack.name),
          if (_packsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (_packsFailed)
            TextButton.icon(
              onPressed: _loadPacks,
              icon: const Icon(Icons.refresh),
              label: const Text('Load categories'),
            ),
        ],
      ),
    );
  }

  Widget _categoryChip(String id, String label) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _category == id,
          onSelected: (_) => _selectCategory(id),
        ),
      );

  Widget _ballGrid(List<CustomBall> balls) {
    if (balls.isEmpty) return const Center(child: Text('No balls here yet.'));
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisExtent: 104,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: balls.length,
      itemBuilder: (context, index) {
        final ball = balls[index];
        final selected = _selected.containsKey(ball.id);
        return GestureDetector(
          onTap: () => _toggle(ball),
          child: Column(
            children: [
              Stack(
                children: [
                  Opacity(
                    opacity: selected || _selected.length < _maxBalls ? 1.0 : 0.35,
                    child: CircularBallPreview(ball: ball, size: 64),
                  ),
                  if (selected)
                    const Positioned(
                      right: 0,
                      top: 0,
                      child: CircleAvatar(radius: 11, child: Icon(Icons.check, size: 15)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ball.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _selectionBar() {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Text('${_selected.length}/$_maxBalls'),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final ball in _selected.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      avatar: CircularBallPreview(ball: ball, size: 22),
                      label: Text(ball.name),
                      onDeleted: () => _toggle(ball),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
