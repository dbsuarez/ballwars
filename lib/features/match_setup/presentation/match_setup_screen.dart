import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_packs/data/ball_pack_repository.dart';
import '../../ball_packs/domain/ball_pack.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../custom_groups/domain/custom_group.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/offline/device_prefs.dart';
import '../../settings/data/effects_prefs.dart';
import '../../replay_export/domain/replay_link.dart';
import '../domain/match_config.dart';

/// Pick 2-4 balls from the built-in packs (Streaming, Countries, ...) or
/// your own groups, mixing categories freely, then start the battle.
class MatchSetupScreen extends StatefulWidget {
  /// Built-in packs; null hides them (e.g. in tests or offline builds).
  final BallPackRepository? packRepository;

  /// The user's own groups (My Groups); null hides them.
  final CustomGroupRepository? customGroups;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({
    super.key,
    this.packRepository,
    this.customGroups,
    required this.onStartBattle,
  });

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

  /// Yes or No: the question the match answers.
  final TextEditingController _question = TextEditingController();
  // The category box's text: selected on focus so typing replaces it.
  final TextEditingController _categoryText = TextEditingController();
  final math.Random _random = math.Random();
  double _speedMultiplier = 1.0;
  bool _showEffects = true;
  WallSparkSize _wallSparkSize = WallSparkSize.normal;
  BallSize _ballSize = BallSize.medium;
  MatchMode _mode = MatchMode.threads;
  BallLook _look = BallLook.pictures;

  /// Power-up modes: the chosen power-ups, null for all.
  Set<PowerUpKind>? _powerUps;
  bool _dualWield = false;
  bool _endlessBattle = false;
  bool _shrinkingArena = false;

  /// Which kind of categories the dropdown lists; remembered per device.
  _CategoryFilter _filter = _CategoryFilter.defaults;
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
    _loadPrefs();
  }

  /// Rounds, speed and effects start the way this device last left them.
  Future<void> _loadPrefs() async {
    final effects = await EffectsPrefs.effectsOn();
    final wallSparkSize = WallSparkSize.byId(
      await DevicePrefs.read('wall-spark-size'),
    );
    final rounds = int.tryParse(await DevicePrefs.read('rounds') ?? '');
    final speed = double.tryParse(await DevicePrefs.read('speed') ?? '');
    final size = BallSize.byId(await DevicePrefs.read('size'));
    final mode = MatchMode.byId(await DevicePrefs.read('mode'));
    final look = BallLook.byName(await DevicePrefs.read('look'));
    final dualWield = await DevicePrefs.read('dual-wield');
    final endlessBattle = await DevicePrefs.read('endless-battle');
    final shrinkingArena = await DevicePrefs.read('shrinking-arena');
    final savedKinds = {
      for (final name in (await DevicePrefs.read('power-ups') ?? '').split(','))
        ...PowerUpKind.values.where((k) => k.name == name),
    };
    final filter = _CategoryFilter.byName(
      await DevicePrefs.read('category-filter'),
    );
    if (!mounted) return;
    setState(() {
      if (filter != null && filter != _filter) {
        _filter = filter;
        _category = _shown.firstOrNull?.id;
      }
      if (size != null) _ballSize = size;
      if (mode != null) _mode = mode;
      if (look != null) _look = look;
      _dualWield = dualWield == '1';
      _endlessBattle = endlessBattle == '1';
      _shrinkingArena = shrinkingArena == '1';
      if (savedKinds.isNotEmpty &&
          savedKinds.length < PowerUpKind.values.length) {
        _powerUps = {
          ...savedKinds.where((kind) => !kind.isTrap),
          ...PowerUpKind.values.where((kind) => kind.isTrap),
        };
      }
      _showEffects = effects;
      if (wallSparkSize != null) _wallSparkSize = wallSparkSize;
      if (rounds != null && const [1, 2, 3].contains(rounds)) {
        _winsNeeded = rounds;
      }
      if (speed != null && _speeds.contains(speed)) _speedMultiplier = speed;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _question.dispose();
    _categoryText.dispose();
    super.dispose();
  }

  List<BallPack> get _categories =>
      [..._groups, ..._packsWithExtras]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// Groups the admin added to built-in categories (see [CustomGroup.packId]).
  List<CustomGroup> _packExtras = const [];

  /// The built-in packs with the admin's extra balls appended, plus groups
  /// the admin made main categories of their own.
  List<BallPack> get _packsWithExtras => [
    for (final pack in _packs)
      BallPack(
        id: pack.id,
        name: pack.name,
        tag: pack.tag,
        balls: [
          ...pack.balls,
          for (final g in _packExtras)
            if (g.packId == pack.id) ...g.balls,
        ],
      ),
    for (final g in _packExtras)
      if (g.packId == CustomGroup.ownCategory && g.balls.isNotEmpty)
        // Not 'group:<id>': the same group may also be listed as Mine/Shared.
        BallPack(id: 'main:${g.id}', name: g.name, balls: g.balls),
  ];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _packsFailed = false;
    });
    await Future.wait([_loadGroups(), _loadPacks()]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _category ??= _shown.firstOrNull?.id;
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
    Future<List<CustomGroup>> orNone(
      Future<List<CustomGroup>> Function() load,
    ) async {
      try {
        return await load();
      } catch (_) {
        return const [];
      }
    }

    final mine = await orNone(repo.myGroups);
    final saved = await orNone(repo.savedGroups);
    final extras = await orNone(repo.packExtras);
    if (!mounted) return;
    final mineIds = {for (final g in mine) g.id};
    _packExtras = extras;
    setState(
      () => _groups = [
        for (final g in mine)
          if (g.balls.isNotEmpty)
            BallPack(
              id: 'group:${g.id}',
              name: g.name,
              balls: g.balls,
              tag: 'Mine',
            ),
        for (final g in saved)
          if (g.balls.isNotEmpty && !mineIds.contains(g.id))
            BallPack(
              id: 'group:${g.id}',
              name: g.name,
              balls: g.balls,
              tag: 'Shared',
            ),
      ],
    );
  }

  /// The categories the current filter shows (Mine / Default / Shared).
  List<BallPack> get _shown => [
    for (final c in _categories)
      if (c.tag == _filter.tag) c,
  ];

  void _setFilter(_CategoryFilter filter) {
    GameAudio.instance.click();
    DevicePrefs.write('category-filter', filter.name);
    setState(() {
      _filter = filter;
      _selected.clear();
      _category = _shown.firstOrNull?.id;
      _categoryText.text = _shown.firstOrNull?.name ?? '';
      _search.clear();
    });
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
    return query.isEmpty
        ? balls
        : balls.where((b) => b.name.toLowerCase().contains(query)).toList();
  }

  void _toggle(CustomBall ball) {
    GameAudio.instance.click();
    setState(() {
      if (_selected.remove(ball.id) == null && _selected.length < _maxBalls) {
        _selected[ball.id] = ball;
      }
    });
  }

  /// Opens the weapons list; the choice is remembered on the device.
  Future<void> _chooseWeapons() async {
    GameAudio.instance.click();
    final chosen = await showDialog<Set<PowerUpKind>>(
      context: context,
      builder: (_) => _WeaponsDialog(
        initial: {
          ...?_powerUps,
          ...PowerUpKind.values.where((kind) => kind.isTrap),
          if (_powerUps == null)
            ...PowerUpKind.values.where((kind) => !kind.isTrap),
        },
        arsenal: _mode == MatchMode.arsenal,
        config: AppSettingsScope.of(context).powerUps,
      ),
    );
    if (chosen == null || !mounted) return;
    final all = chosen.length == PowerUpKind.values.length;
    setState(() => _powerUps = all ? null : chosen);
    DevicePrefs.write('power-ups', [for (final k in chosen) k.name].join(','));
  }

  void _clearPicks() {
    GameAudio.instance.click();
    setState(_selected.clear);
  }

  void _randomMatchup() {
    final pool = [..._categoryBalls]..shuffle(_random);
    if (pool.length < 2) return;
    GameAudio.instance.click();
    setState(() {
      _selected
        ..clear()
        ..addEntries(pool.take(2).map((b) => MapEntry(b.id, b)));
    });
  }

  bool get _canStart => _selected.length >= 2 && _selected.length <= _maxBalls;

  void _start() {
    if (!_canStart) return;
    GameAudio.instance.click();
    widget.onStartBattle(
      MatchConfig(
        contestants: _selected.values.toList(),
        speedMultiplier: _speedMultiplier,
        showEffects: _showEffects,
        wallSparkSize: _wallSparkSize,
        winsNeeded: _winsNeeded,
        ballSize: _ballSize,
        mode: _mode,
        look: _look,
        powerUps: _mode == MatchMode.threads ? null : _powerUps,
        dualWield: _mode != MatchMode.threads && _dualWield,
        endlessBattle: _mode == MatchMode.arsenal && _endlessBattle,
        shrinkingArena: _shrinkingArena,
        // The admin's power-up numbers; part of the match (and of its replay link).
        tuning: _mode == MatchMode.threads
            ? PowerUpConfig.defaults
            : AppSettingsScope.of(context).powerUps,
        // Only for matches with Yes or No balls.
        question:
            _selected.keys.any((id) => id.startsWith('pack:$_decisionPack/'))
            ? ReplayLink.cleanQuestion(_question.text)
            : null,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: _categoryPicker(c),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_CategoryFilter>(
          segments: [
            for (final f in _CategoryFilter.values)
              ButtonSegment(value: f, label: Text(f.label)),
          ],
          selected: {_filter},
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          onSelectionChanged: (v) => _setFilter(v.first),
        ),
        const SizedBox(height: 12),
        _categoryDropdown(c),
        // Yes or No: ask a question; the winning ball is the answer.
        if (_category == _decisionPack) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            maxLength: ReplayLink.maxQuestionLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Your question',
              hintText: 'Will it rain tomorrow?',
            ),
          ),
        ],
      ],
    );
  }

  /// The built-in "Yes or No" pack.
  static const String _decisionPack = 'decision';

  Widget _categoryDropdown(BallWarsColors c) {
    final categories = _shown;
    if (categories.isEmpty) {
      if (_loading) return const LinearProgressIndicator();
      if (_filter != _CategoryFilter.defaults) {
        return Text(
          _filter == _CategoryFilter.mine
              ? 'No groups of your own yet. Make one in My groups on the home screen.'
              : 'No shared groups yet. Open a group link from a friend to add one.',
          style: AppText.ui(14, FontWeight.w500, color: c.muted, height: 1.4),
        );
      }
      return Row(
        children: [
          Expanded(
            child: Text(
              _packsFailed
                  ? "Couldn't load the categories."
                  : 'No categories yet.',
              style: AppText.ui(14, FontWeight.w500, color: c.muted),
            ),
          ),
          if (_packsFailed)
            TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      );
    }
    final selectedName =
        categories.where((p) => p.id == _category).firstOrNull?.name ?? '';
    return LayoutBuilder(
      builder: (context, constraints) => Focus(
        onFocusChange: (focused) {
          if (focused) {
            // After the tap that focused it has placed the caret.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _categoryText.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _categoryText.text.length,
              ),
            );
          } else {
            _categoryText.text =
                selectedName; // left without picking: show the current one again
          }
        },
        child: DropdownMenu<String>(
          key: ValueKey('${_filter.name}-${categories.length}'),
          controller: _categoryText,
          width: constraints.maxWidth,
          initialSelection: _category,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 360,
          leadingIcon: const Icon(Icons.search),
          label: const Text('Category'),
          textStyle: AppText.ui(15, FontWeight.w600, color: c.text),
          onSelected: (id) {
            // Enter on typed text that matches nothing reports null: keep the
            // current category rather than showing an empty one.
            if (id == null) return;
            setState(() {
              // A match never mixes categories: a new category starts with no picks.
              if (id != _category) _selected.clear();
              _category = id;
              _search.clear();
            });
          },
          dropdownMenuEntries: [
            for (final pack in categories)
              DropdownMenuEntry(
                value: pack.id,
                label: pack.name,
                trailingIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pack.tag != null) ...[
                      _Tag(pack.tag!),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${pack.balls.length}',
                      style: AppText.mono(12, color: c.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _ballGrid(BallWarsColors c, List<CustomBall> balls) {
    if (_loading && balls.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (balls.isEmpty) {
      return Center(
        child: Text(
          'No balls here yet.',
          style: AppText.ui(14, FontWeight.w500, color: c.muted),
        ),
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
                      border: Border.all(
                        color: selected ? c.text : Colors.transparent,
                        width: 2,
                      ),
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
          // The kind of match: the thread game, weapons only, or both.
          SegmentedButton<MatchMode>(
            segments: [
              for (final m in MatchMode.values)
                ButtonSegment(value: m, label: Text(m.label)),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            onSelectionChanged: (v) {
              GameAudio.instance.click();
              setState(() => _mode = v.first);
              DevicePrefs.write('mode', v.first.id);
            },
          ),
          if (_mode != MatchMode.threads) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseWeapons,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                _powerUps == null
                    ? 'Pickups: All'
                    : 'Pickups: ${_powerUps!.where((kind) => !kind.isTrap).length} of '
                          '${PowerUpKind.values.where((kind) => !kind.isTrap).length}',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Dual wield'),
              subtitle: const Text('Equip up to two weapons'),
              value: _dualWield,
              onChanged: (value) {
                GameAudio.instance.click();
                setState(() => _dualWield = value);
                DevicePrefs.write('dual-wield', value ? '1' : '0');
              },
            ),
            if (_mode == MatchMode.arsenal)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Endless Battle'),
                subtitle: const Text(
                  'Respawn at full health and count knockouts',
                ),
                value: _endlessBattle,
                onChanged: (value) {
                  GameAudio.instance.click();
                  setState(() => _endlessBattle = value);
                  DevicePrefs.write('endless-battle', value ? '1' : '0');
                },
              ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Shrinking arena'),
            subtitle: const Text(
              'After 10 seconds, the boundary contracts to 60% over 2 minutes',
            ),
            value: _shrinkingArena,
            onChanged: (value) {
              GameAudio.instance.click();
              setState(() => _shrinkingArena = value);
              DevicePrefs.write('shrinking-arena', value ? '1' : '0');
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Text(
                  '${_selected.length}/$_maxBalls',
                  style: AppText.mono(12, color: c.muted),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _selected.isEmpty
                      ? Text(
                          'Pick 2 to 4 balls',
                          style: AppText.ui(
                            13,
                            FontWeight.w500,
                            color: c.muted,
                          ),
                        )
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final ball in _selected.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InputChip(
                                  avatar: CircularBallPreview(
                                    ball: ball,
                                    size: 22,
                                  ),
                                  label: Text(
                                    ball.name,
                                    style: AppText.ui(
                                      13,
                                      FontWeight.w600,
                                      color: c.text,
                                    ),
                                  ),
                                  onDeleted: () => _toggle(ball),
                                  backgroundColor: c.surfaceHigh,
                                  side: BorderSide.none,
                                  shape: const StadiumBorder(),
                                ),
                              ),
                          ],
                        ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: _clearPicks,
                    style: TextButton.styleFrom(
                      foregroundColor: c.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Clear'),
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
                    onChanged: (v) {
                      GameAudio.instance.click();
                      setState(() => _winsNeeded = v);
                      DevicePrefs.write('rounds', v);
                    },
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
                    onChanged: (v) {
                      GameAudio.instance.click();
                      setState(() => _speedMultiplier = v);
                      DevicePrefs.write('speed', v);
                    },
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
                    onChanged: (v) {
                      GameAudio.instance.click();
                      setState(() => _showEffects = v);
                      EffectsPrefs.setEffectsOn(v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Setting(
                  label: 'SIZE',
                  child: _Cycle<BallSize>(
                    values: BallSize.values,
                    value: _ballSize,
                    label: (v) => v.label,
                    onChanged: (v) {
                      GameAudio.instance.click();
                      setState(() => _ballSize = v);
                      DevicePrefs.write('size', v.id);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Setting(
            label: 'WALL SPARKS',
            child: _Cycle<WallSparkSize>(
              values: WallSparkSize.values,
              value: _wallSparkSize,
              label: (value) => value.label,
              onChanged: (value) {
                GameAudio.instance.click();
                setState(() => _wallSparkSize = value);
                DevicePrefs.write('wall-spark-size', value.id);
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _SoundToggle(
                on: GameAudio.instance.musicOn,
                icon: Icons.music_note_rounded,
                offIcon: Icons.music_off_rounded,
                tooltip: 'Music',
                onChanged: (on) async {
                  await GameAudio.instance.setMusicOn(on);
                  GameAudio.instance.click();
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              _SoundToggle(
                on: GameAudio.instance.effectsOn,
                icon: Icons.volume_up_rounded,
                offIcon: Icons.volume_off_rounded,
                tooltip: 'Sound effects',
                onChanged: (on) async {
                  await GameAudio.instance.setEffectsOn(on);
                  GameAudio.instance.click();
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              // Ball look: pictures or smiley faces (cosmetic, remembered).
              SizedBox(
                width: 48,
                height: 52,
                child: Tooltip(
                  message: 'Ball look: ${_look.name}',
                  child: OutlinedButton(
                    onPressed: () {
                      GameAudio.instance.click();
                      final next = _look == BallLook.pictures
                          ? BallLook.faces
                          : BallLook.pictures;
                      setState(() => _look = next);
                      DevicePrefs.write('look', next.name);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(48, 52),
                    ),
                    child: Icon(
                      _look == BallLook.faces
                          ? Icons.sentiment_satisfied_alt_rounded
                          : Icons.image_outlined,
                      semanticLabel: 'Ball look',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                height: 52,
                child: OutlinedButton(
                  onPressed: _categoryBalls.length >= 2 ? _randomMatchup : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(56, 52),
                  ),
                  child: const Icon(
                    Icons.shuffle,
                    semanticLabel: 'Random matchup',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _canStart ? _start : null,
                  child: const Text('Start'),
                ),
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
          Text(
            label,
            style: AppText.ui(
              10,
              FontWeight.w700,
              color: c.muted,
              letterSpacing: 0.8,
            ),
          ),
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

  const _Cycle({
    required this.values,
    required this.value,
    required this.label,
    required this.onChanged,
  });

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
      // One line; long values ("First to 3") shrink a little in narrow tiles.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label(value),
          maxLines: 1,
          style: AppText.ui(14, FontWeight.w700, color: c.text),
        ),
      ),
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.border),
      ),
      child: Text(
        label,
        style: AppText.ui(
          10,
          FontWeight.w700,
          color: c.muted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Music / sound effects on-off button; crossed-out icon when off.
class _SoundToggle extends StatelessWidget {
  final bool on;
  final IconData icon;
  final IconData offIcon;
  final String tooltip;
  final ValueChanged<bool> onChanged;

  const _SoundToggle({
    required this.on,
    required this.icon,
    required this.offIcon,
    required this.tooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return SizedBox(
      width: 48,
      height: 52,
      child: Tooltip(
        message: '$tooltip: ${on ? 'on' : 'off'}',
        child: OutlinedButton(
          onPressed: () => onChanged(!on),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 52),
          ),
          child: Icon(
            on ? icon : offIcon,
            color: on ? c.text : c.muted,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// The category filter above the dropdown: the user's own groups, the
/// built-in packs (Default), or groups added from others.
enum _CategoryFilter {
  mine('Mine', 'Mine'),
  defaults('Default', null),
  shared('Shared', 'Shared');

  final String label;

  /// The [BallPack.tag] of the categories it shows (null: built-in packs).
  final String? tag;

  const _CategoryFilter(this.label, this.tag);

  static _CategoryFilter? byName(String? name) =>
      values.where((f) => f.name == name).firstOrNull;
}

/// Which power-ups can spawn: compact cards with an icon, description and
/// corner checkmark. Done needs at least one selection.
class _WeaponsDialog extends StatefulWidget {
  final Set<PowerUpKind> initial;
  final bool arsenal;
  final PowerUpConfig config;

  const _WeaponsDialog({
    required this.initial,
    required this.arsenal,
    required this.config,
  });

  @override
  State<_WeaponsDialog> createState() => _WeaponsDialogState();
}

class _WeaponsDialogState extends State<_WeaponsDialog> {
  late final Set<PowerUpKind> _on = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final weapons = PowerUpKind.values.where((kind) => kind.isWeapon);
    final powerUps = PowerUpKind.values.where((kind) => kind.isPowerUp);
    final traps = PowerUpKind.values.where((kind) => kind.isTrap);
    final selectable = PowerUpKind.values.where((kind) => !kind.isTrap);
    final selectedCount = selectable.where(_on.contains).length;
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 760),
      title: const Text('Weapons, power-ups & traps'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 720,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (widget.arsenal)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  crowdNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Pick at least one.'
                          : '$selectedCount selected',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selectedCount == 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _on.addAll(selectable)),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _on.removeAll(selectable)),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _section('Weapons', weapons),
            _section('Power-ups', powerUps),
            _trapSection(traps),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // At least one has to stay on.
        FilledButton(
          onPressed: selectedCount == 0
              ? null
              : () => Navigator.of(context).pop(_on),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _section(String title, Iterable<PowerUpKind> kinds) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      _cardGrid(kinds, selectable: true),
    ],
  );

  Widget _trapSection(Iterable<PowerUpKind> kinds) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          'Traps - always on',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      _cardGrid(kinds, selectable: false),
    ],
  );

  Widget _cardGrid(Iterable<PowerUpKind> kinds, {required bool selectable}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth >= 560 ? 2 : 1;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final kind in kinds)
                  SizedBox(
                    width: width - (columns == 1 ? 16 : 8),
                    height: 112,
                    child: _itemCard(kind, selectable: selectable),
                  ),
              ],
            ),
          );
        },
      );

  Widget _itemCard(PowerUpKind kind, {required bool selectable}) {
    final selected = selectable ? _on.contains(kind) : true;
    final colors = Theme.of(context).colorScheme;
    final appColors = BallWarsColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? appColors.surfaceHigh : appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? appColors.text : appColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('selection-card-${kind.name}'),
        onTap: selectable
            ? () => setState(() => selected ? _on.remove(kind) : _on.add(kind))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PowerUpIcon(kind, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: appColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      powerUpDescription(
                        kind,
                        arsenal: widget.arsenal,
                        config: widget.config,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: appColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selectable
                    ? selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined
                    : Icons.lock_outline_rounded,
                size: 22,
                color: selectable && selected ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
