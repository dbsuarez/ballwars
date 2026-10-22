import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_packs/data/ball_pack_repository.dart';
import '../../ball_packs/domain/ball_pack.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../custom_groups/domain/custom_group.dart';
import '../domain/match_config.dart';

/// Pick 2-4 balls from the built-in packs (Streaming, Countries, ...) or
/// your own groups, mixing categories freely, then start the battle.
class MatchSetupScreen extends StatefulWidget {
  /// Built-in packs; null hides them (e.g. in tests or offline builds).
  final BallPackRepository? packRepository;

  /// The user's own groups (My Groups); null hides them.
  final CustomGroupRepository? customGroups;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({super.key, this.packRepository, this.customGroups, required this.onStartBattle});

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  static const int _maxBalls = 4;
  static const int _searchFrom = 20;
  static const List<double> _speeds = [0.5, 1, 2];

  // Insertion-ordered: contestants keep the order they were picked in.
  final Map<String, CustomBall> _selected = {};
  final TextEditingController _search = TextEditingController();
  // The category box's text: selected on focus so typing replaces it.
  final TextEditingController _categoryText = TextEditingController();
  final math.Random _random = math.Random();
  double _speedMultiplier = 1.0;
  bool _showEffects = true;
  int _winsNeeded = 1;
  String? _category;
  List<BallPack> _packs = const [];
  // The user's groups, listed before the built-in packs.
  List<BallPack> _groups = const [];
  bool _loading = false;
  bool _packsFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _categoryText.dispose();
    super.dispose();
  }

  List<BallPack> get _categories =>
      [..._groups, ..._packs]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _packsFailed = false;
    });
    await Future.wait([_loadGroups(), _loadPacks()]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _category ??= _categories.isEmpty ? null : _categories.first.id;
    });
  }

  Future<void> _loadPacks() async {
    final repo = widget.packRepository;
    if (repo == null) return;
    try {
      final packs = await repo.load();
      if (mounted) setState(() => _packs = packs);
    } catch (_) {
      if (mounted) setState(() => _packsFailed = true);
    }
  }

  /// The user's own groups (tagged Mine) and the ones they added from other
  /// players (Shared). Groups that fail to load (offline, not set up) just
  /// don't show.
  Future<void> _loadGroups() async {
    final repo = widget.customGroups;
    if (repo == null) return;
    Future<List<CustomGroup>> orNone(Future<List<CustomGroup>> Function() load) async {
      try {
        return await load();
      } catch (_) {
        return const [];
      }
    }

    final mine = await orNone(repo.myGroups);
    final saved = await orNone(repo.savedGroups);
    if (!mounted) return;
    final mineIds = {for (final g in mine) g.id};
    setState(
      () => _groups = [
        for (final g in mine)
          if (g.balls.isNotEmpty) BallPack(id: 'group:${g.id}', name: g.name, balls: g.balls, tag: 'Mine'),
        for (final g in saved)
          if (g.balls.isNotEmpty && !mineIds.contains(g.id))
            BallPack(id: 'group:${g.id}', name: g.name, balls: g.balls, tag: 'Shared'),
      ],
    );
  }

  List<CustomBall> get _categoryBalls => _categories
      .firstWhere(
        (p) => p.id == _category,
        orElse: () => const BallPack(id: '', name: '', balls: []),
      )
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
    widget.onStartBattle(
      MatchConfig(
        contestants: _selected.values.toList(),
        speedMultiplier: _speedMultiplier,
        showEffects: _showEffects,
        winsNeeded: _winsNeeded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final balls = _visibleBalls;

    return Scaffold(
      appBar: AppBar(title: const Text('New match')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: _categoryPicker(c)),
                if (_categoryBalls.length > _searchFrom)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search',
                        isDense: true,
                      ),
                    ),
                  ),
                Expanded(child: _ballGrid(c, balls)),
                _footer(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryPicker(BallWarsColors c) {
    final categories = _categories;
    if (categories.isEmpty) {
      if (_loading) return const LinearProgressIndicator();
      return Row(
        children: [
          Expanded(
            child: Text(
              _packsFailed ? "Couldn't load the categories." : 'No categories yet.',
              style: AppText.ui(14, FontWeight.w500, color: c.muted),
            ),
          ),
          if (_packsFailed) TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final selectedName = categories.where((p) => p.id == _category).firstOrNull?.name ?? '';
    return LayoutBuilder(
      builder: (context, constraints) => Focus(
        onFocusChange: (focused) {
          if (focused) {
            // After the tap that focused it has placed the caret.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _categoryText.selection = TextSelection(baseOffset: 0, extentOffset: _categoryText.text.length),
            );
          } else {
            _categoryText.text = selectedName; // left without picking: show the current one again
          }
        },
        child: DropdownMenu<String>(
          key: ValueKey(categories.length),
          controller: _categoryText,
          width: constraints.maxWidth,
          initialSelection: _category,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 360,
          leadingIcon: const Icon(Icons.search),
          label: const Text('Category'),
          textStyle: AppText.ui(15, FontWeight.w600, color: c.text),
          onSelected: (id) => setState(() {
            _category = id;
            _search.clear();
          }),
          dropdownMenuEntries: [
            for (final pack in categories)
              DropdownMenuEntry(
                value: pack.id,
                label: pack.name,
                trailingIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pack.tag != null) ...[_Tag(pack.tag!), const SizedBox(width: 10)],
                    Text('${pack.balls.length}', style: AppText.mono(12, color: c.muted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ballGrid(BallWarsColors c, List<CustomBall> balls) {
    if (_loading && balls.isEmpty) return const Center(child: CircularProgressIndicator());
    if (balls.isEmpty) {
      return Center(
        child: Text('No balls here yet.', style: AppText.ui(14, FontWeight.w500, color: c.muted)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        mainAxisExtent: 112,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
      ),
      itemCount: balls.length,
      itemBuilder: (context, index) {
        final ball = balls[index];
        final selected = _selected.containsKey(ball.id);
        final full = !selected && _selected.length >= _maxBalls;
        return Semantics(
          button: true,
          selected: selected,
          label: ball.name,
          child: InkWell(
            onTap: () => _toggle(ball),
            borderRadius: BorderRadius.circular(14),
            child: Opacity(
              opacity: full ? 0.35 : 1,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? c.text : Colors.transparent, width: 2),
                    ),
                    child: CircularBallPreview(ball: ball, size: 56),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ball.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppText.ui(
                      12,
                      selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? c.text : c.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _footer(BallWarsColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Text('${_selected.length}/$_maxBalls', style: AppText.mono(12, color: c.muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: _selected.isEmpty
                      ? Text('Pick 2 to 4 balls', style: AppText.ui(13, FontWeight.w500, color: c.muted))
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final ball in _selected.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InputChip(
                                  avatar: CircularBallPreview(ball: ball, size: 22),
                                  label: Text(ball.name, style: AppText.ui(13, FontWeight.w600, color: c.text)),
                                  onDeleted: () => _toggle(ball),
                                  backgroundColor: c.surfaceHigh,
                                  side: BorderSide.none,
                                  shape: const StadiumBorder(),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Setting(
                  label: 'ROUNDS',
                  child: _Cycle<int>(
                    values: const [1, 2, 3],
                    value: _winsNeeded,
                    label: (v) => v == 1 ? '1 round' : 'First to $v',
                    onChanged: (v) => setState(() => _winsNeeded = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Setting(
                  label: 'SPEED',
                  child: _Cycle<double>(
                    values: _speeds,
                    value: _speedMultiplier,
                    label: (v) => '${v == v.roundToDouble() ? v.toInt() : v}×',
                    onChanged: (v) => setState(() => _speedMultiplier = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Setting(
                  label: 'EFFECTS',
                  child: _Cycle<bool>(
                    values: const [true, false],
                    value: _showEffects,
                    label: (v) => v ? 'On' : 'Off',
                    onChanged: (v) => setState(() => _showEffects = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 52,
                child: OutlinedButton(
                  onPressed: _categoryBalls.length >= 2 ? _randomMatchup : null,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 52)),
                  child: const Icon(Icons.shuffle, semanticLabel: 'Random matchup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(onPressed: _canStart ? _start : null, child: const Text('Start')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A compact labelled setting tile.
class _Setting extends StatelessWidget {
  final String label;
  final Widget child;

  const _Setting({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.ui(10, FontWeight.w700, color: c.muted, letterSpacing: 0.8)),
          child,
        ],
      ),
    );
  }
}

/// Tap to step through [values] (keeps the settings row to one line).
class _Cycle<T> extends StatelessWidget {
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _Cycle({required this.values, required this.value, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final next = values[(values.indexOf(value) + 1) % values.length];
    return TextButton(
      onPressed: () => onChanged(next),
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 36),
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label(value), style: AppText.ui(14, FontWeight.w700, color: c.text)),
    );
  }
}

/// "Mine" / "Shared" next to a user group in the category list.
class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: c.border)),
      child: Text(label, style: AppText.ui(10, FontWeight.w700, color: c.muted, letterSpacing: 0.4)),
    );
  }
}
