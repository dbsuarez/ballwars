import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../../settings/domain/app_settings.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/power_up_name.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../ball_management/presentation/widgets/circular_ball_preview.dart';
import '../../ball_packs/data/ball_pack_repository.dart';
import '../../ball_packs/domain/ball_pack.dart';
import '../../custom_groups/data/custom_group_repository.dart';
import '../../custom_groups/domain/custom_group.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/offline/device_prefs.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../settings/data/effects_prefs.dart';
import '../../skills/domain/skill_library.dart';
import '../../replay_export/domain/replay_link.dart';
import '../domain/match_config.dart';

/// Pick 2-4 balls from the built-in packs (Streaming, Countries, ...) or
/// your own groups, mixing categories freely, then start the battle.
class MatchSetupScreen extends StatefulWidget {
  /// Built-in packs; null hides them (e.g. in tests or offline builds).
  final BallPackRepository? packRepository;
  final MatchMode? initialMode;
  final bool initialMayhem;

  /// The user's own groups (My Groups); null hides them.
  final CustomGroupRepository? customGroups;
  final void Function(MatchConfig) onStartBattle;

  const MatchSetupScreen({
    super.key,
    this.packRepository,
    this.initialMode,
    this.initialMayhem = false,
    this.customGroups,
    required this.onStartBattle,
  });

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  int get _maxBalls => _mayhem ? 6 : 4;
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
  bool _automaticSpeedUp = true;
  bool _showEffects = true;
  WallSparkSize _wallSparkSize = WallSparkSize.normal;
  BallSize _ballSize = BallSize.medium;
  MatchMode _mode = MatchMode.threads;
  BallLook _look = BallLook.pictures;
  bool _handsOnPictures = false;
  bool _whitePickupBackgrounds = true;
  bool _randomizedHairstyles = false;

  /// Power-up modes: the chosen power-ups, null for all.
  Set<PowerUpKind>? _powerUps;
  final Map<String, Set<PowerUpKind>?> _modePowerUps = {};
  VoidCallback? _refreshDrawer;

  void _update(VoidCallback update) {
    setState(update);
    _refreshDrawer?.call();
  }

  String _profileId(MatchMode mode, {required bool mayhem}) =>
      mayhem ? 'mayhem' : mode.id;

  String get _activeProfileId => _profileId(_mode, mayhem: _mayhem);

  String _profileKey(MatchMode mode, String setting, {required bool mayhem}) =>
      'match-${_profileId(mode, mayhem: mayhem)}-$setting';

  Future<String?> _readProfile(
    MatchMode mode,
    String setting, {
    required bool mayhem,
    String? legacyKey,
  }) async =>
      await DevicePrefs.read(_profileKey(mode, setting, mayhem: mayhem)) ??
      await DevicePrefs.read(legacyKey ?? setting);

  void _writeProfile(String setting, Object value) =>
      DevicePrefs.write(_profileKey(_mode, setting, mayhem: _mayhem), value);

  bool _dualWield = false;
  bool _endlessBattle = false;
  bool _mayhem = false;
  int _mayhemSeconds = 120;
  bool _shrinkingArena = false;
  ArenaDecoration? _arenaDecoration;
  bool _finishersOn = true;
  bool _settingCards = true;
  int _settingsTab = 0;

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
    _mode = widget.initialMode ?? MatchMode.threads;
    _mayhem = widget.initialMayhem && _mode == MatchMode.arsenal;
    _load();
    _loadPrefs();
  }

  /// Rounds, speed and effects start the way this device last left them.
  Future<void> _loadPrefs({bool? mayhemOverride}) async {
    final rememberedMode = MatchMode.byId(await DevicePrefs.read('mode'));
    final profileMode =
        widget.initialMode ?? rememberedMode ?? MatchMode.threads;
    final profileMayhem =
        mayhemOverride ??
        (widget.initialMode != null
            ? widget.initialMayhem && profileMode == MatchMode.arsenal
            : (profileMode == MatchMode.arsenal &&
                  await DevicePrefs.read('mayhem') == '1'));
    final effects =
        await _readProfile(profileMode, 'effects', mayhem: profileMayhem) ??
        ((await EffectsPrefs.effectsOn()) ? '1' : '0');
    final finishers =
        await _readProfile(profileMode, 'finishers', mayhem: profileMayhem) ??
        ((await EffectsPrefs.finishersOn()) ? '1' : '0');
    final settingCards =
        await DevicePrefs.read('match-settings-layout') != 'list';
    final wallSparkSize = WallSparkSize.byId(
      await _readProfile(profileMode, 'wall-spark-size', mayhem: profileMayhem),
    );
    final rounds = int.tryParse(
      await _readProfile(profileMode, 'rounds', mayhem: profileMayhem) ?? '',
    );
    final speed = double.tryParse(
      await _readProfile(profileMode, 'speed', mayhem: profileMayhem) ?? '',
    );
    final automaticSpeedUp = await _readProfile(
      profileMode,
      'automatic-speed-up',
      mayhem: profileMayhem,
    );
    final size = BallSize.byId(
      await _readProfile(profileMode, 'size', mayhem: profileMayhem),
    );
    final mode = profileMode;
    final look = BallLook.byName(
      await _readProfile(profileMode, 'look', mayhem: profileMayhem),
    );
    final handsOnPictures = await _readProfile(
      profileMode,
      'hands-on-pictures',
      mayhem: profileMayhem,
    );
    final whitePickupBackgrounds = await _readProfile(
      profileMode,
      'white-pickup-backgrounds',
      mayhem: profileMayhem,
    );
    final randomizedHairstyles = await _readProfile(
      profileMode,
      'randomized-hairstyles',
      mayhem: profileMayhem,
    );
    final dualWield = await _readProfile(
      profileMode,
      'dual-wield',
      mayhem: profileMayhem,
    );
    final endlessBattle = await _readProfile(
      profileMode,
      'endless-battle',
      mayhem: profileMayhem,
    );
    final duration =
        int.tryParse(
          await _readProfile(
                profileMode,
                'mayhem-seconds',
                mayhem: profileMayhem,
              ) ??
              '120',
        ) ??
        120;
    final shrinkingArena = await _readProfile(
      profileMode,
      'shrinking-arena',
      mayhem: profileMayhem,
    );
    final arenaDecoration = await _readProfile(
      profileMode,
      'arena-decoration-user',
      mayhem: profileMayhem,
    );
    final legacy = await DevicePrefs.read('power-ups');
    final profileIds = [...MatchMode.values.map((mode) => mode.id), 'mayhem'];
    for (final profileId in profileIds) {
      final saved = await DevicePrefs.read('power-ups-$profileId') ?? legacy;
      final kinds = {
        for (final name in (saved ?? '').split(','))
          ...PowerUpKind.values.where((kind) => kind.name == name),
      };
      _modePowerUps[profileId] =
          kinds.isEmpty || kinds.length == PowerUpKind.values.length
          ? null
          : {
              ...kinds.where((kind) => !kind.isTrap),
              ...PowerUpKind.values.where((kind) => kind.isTrap),
            };
    }
    final filter = _CategoryFilter.byName(
      await DevicePrefs.read('category-filter'),
    );
    if (!mounted) return;
    _update(() {
      if (filter != null && filter != _filter) {
        _filter = filter;
        _category = _shown.firstOrNull?.id;
      }
      _ballSize = size ?? BallSize.medium;
      _mode = mode;
      _look = look ?? BallLook.pictures;
      _handsOnPictures = handsOnPictures == '1';
      _whitePickupBackgrounds = whitePickupBackgrounds != '0';
      _randomizedHairstyles = randomizedHairstyles == '1';
      _dualWield = dualWield == '1';
      _endlessBattle = endlessBattle == '1';
      _mayhem = profileMayhem && _mode == MatchMode.arsenal;
      _mayhemSeconds = const [30, 60, 120, 180, 300, 600].contains(duration)
          ? duration
          : 120;
      _shrinkingArena = shrinkingArena == '1';
      _arenaDecoration = ArenaDecoration.values
          .where((value) => value.name == arenaDecoration)
          .firstOrNull;
      _powerUps = _modePowerUps[_activeProfileId];
      _showEffects = effects != '0';
      _finishersOn = finishers != '0';
      _settingCards = settingCards;
      _wallSparkSize = wallSparkSize ?? WallSparkSize.normal;
      _winsNeeded = const [1, 2, 3].contains(rounds) ? rounds! : 1;
      _speedMultiplier = _speeds.contains(speed) ? speed! : 1;
      _automaticSpeedUp = automaticSpeedUp != '0';
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
    _update(() {
      _loading = true;
      _packsFailed = false;
    });
    await Future.wait([_loadGroups(), _loadPacks()]);
    if (!mounted) return;
    _update(() {
      _loading = false;
      _category ??= _shown.firstOrNull?.id;
    });
  }

  Future<void> _loadPacks() async {
    final repo = widget.packRepository;
    if (repo == null) return;
    try {
      final packs = await repo.load();
      if (mounted) _update(() => _packs = packs);
    } catch (_) {
      if (mounted) _update(() => _packsFailed = true);
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
    _update(
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
      if (c.tag == _filter.tag && (!_mayhem || c.balls.length >= 6)) c,
  ];

  void _setFilter(_CategoryFilter filter) {
    GameAudio.instance.click();
    DevicePrefs.write('category-filter', filter.name);
    _update(() {
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
    _update(() {
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
        arenaDecoration:
            _arenaDecoration ?? AppSettingsScope.of(context).arenaDecoration,
      ),
    );
    if (chosen == null || !mounted) return;
    final all = chosen.length == PowerUpKind.values.length;
    _update(() => _powerUps = all ? null : chosen);
    _modePowerUps[_activeProfileId] = _powerUps;
    DevicePrefs.write(
      'power-ups-$_activeProfileId',
      [for (final k in chosen) k.name].join(','),
    );
  }

  void _clearPicks() {
    GameAudio.instance.click();
    _update(_selected.clear);
  }

  void _randomMatchup() {
    final pool = [..._categoryBalls]..shuffle(_random);
    final count = _mayhem ? 6 : 2;
    if (pool.length < count) return;
    GameAudio.instance.click();
    _update(() {
      _selected
        ..clear()
        ..addEntries(pool.take(count).map((b) => MapEntry(b.id, b)));
    });
  }

  bool get _canStart => _mayhem
      ? _selected.length == 6
      : _selected.length >= 2 && _selected.length <= _maxBalls;

  void _start() {
    if (!_canStart) return;
    GameAudio.instance.click();
    widget.onStartBattle(
      MatchConfig(
        contestants: _selected.values.toList(),
        speedMultiplier: _speedMultiplier,
        automaticSpeedUp: _automaticSpeedUp,
        showEffects: _showEffects,
        ballGlowWidth: AppSettingsScope.of(context).ballGlowWidth,
        bloodColor: AppSettingsScope.of(context).bloodColor,
        wallSparkSize: _wallSparkSize,
        winsNeeded: _winsNeeded,
        ballSize: _mayhem ? BallSize.small : _ballSize,
        mode: _mayhem ? MatchMode.arsenal : _mode,
        look: _look,
        handsOnPictures: _handsOnPictures,
        whitePickupBackgrounds: _whitePickupBackgrounds,
        randomizedHairstyles: _randomizedHairstyles,
        powerUps: _mode == MatchMode.threads ? null : _powerUps,
        dualWield: _mode != MatchMode.threads && _dualWield,
        endlessBattle:
            _mode == MatchMode.arsenal && (_endlessBattle || _mayhem),
        mayhem: _mode == MatchMode.arsenal && _mayhem,
        mayhemSeconds: _mayhemSeconds,
        shrinkingArena: _shrinkingArena,
        minimumArenaScale: AppSettingsScope.of(context).minimumArenaScale,
        arenaDecoration:
            _arenaDecoration ?? AppSettingsScope.of(context).arenaDecoration,
        // The admin's power-up numbers; part of the match (and of its replay link).
        tuning: _mode == MatchMode.threads
            ? PowerUpConfig.defaults
            : AppSettingsScope.of(context).powerUps,
        skillLibrary: _mode == MatchMode.threads
            ? SkillLibrary.defaults
            : AppSettingsScope.of(context).skillLibrary,
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

    final modeTitle = _mayhem ? 'Mayhem' : _mode.label;
    return Scaffold(
      appBar: AppBar(title: Text(modeTitle)),
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
                      onChanged: (_) => _update(() {}),
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
            _update(() {
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
      return const AnimatedEmptyState(
        message: 'No balls here yet.',
        icon: Icons.sports_baseball_outlined,
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

  Future<void> _settingsInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Match settings guide'),
      content: const SingleChildScrollView(
        child: Text(
          'Choose List or Cards above the settings. Your layout is remembered on this device. Tap anywhere on a row or card to cycle its choices.\n\n'
          'ROUNDS: One round or first to two/three wins.\n'
          'SPEED: Playback at 0.5x, 1x or 2x.\n'
          'PICKUPS: Choose enabled weapons and power-ups; traps stay on.\n'
          'DUAL WIELD: Carry two compatible weapons. Two-handed weapons occupy both slots.\n'
          'MAYHEM: Six balls, your chosen match time, respawns. Most KOs wins; remaining life breaks ties.\n'
          'ENDLESS BATTLE: Respawn eliminated balls and count KOs.\n'
          'SHRINKING ARENA: Boundary contracts after ten seconds.\n'
          'EFFECTS: Show particles and visual feedback.\n'
          'SIZE: Changes every ball equally.\n'
          'WALL SPARKS: Choose the strength of rim-hit sparks.\n'
          'BALL LOOK: Pictures or expressive faces.\n'
          'FINISHERS: Automatically show or skip the finishing cinematic. You can also skip any cinematic with its Skip button.\n'
          'MUSIC / SOUND EFFECTS: Device audio choices. Tap SFX on to hear a confirmation sound.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  Future<void> _openSettings() async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, refresh) {
            _refreshDrawer = () => refresh(() {});
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Match settings'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Match settings info',
                          icon: const Icon(Icons.info_outline),
                          onPressed: _settingsInfo,
                        ),
                        IconButton(
                          tooltip: 'Close match settings',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 220,
                        child: SegmentedButton<bool>(
                          key: const ValueKey('match-settings-layout'),
                          segments: const [
                            ButtonSegment(
                              value: false,
                              icon: Icon(Icons.view_list),
                              label: Text('List'),
                            ),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.grid_view),
                              label: Text('Cards'),
                            ),
                          ],
                          selected: {_settingCards},
                          showSelectedIcon: false,
                          onSelectionChanged: (selected) {
                            final cards = selected.first;
                            _update(() => _settingCards = cards);
                            DevicePrefs.write(
                              'match-settings-layout',
                              cards ? 'cards' : 'list',
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SegmentedButton<int>(
                      key: const ValueKey('match-settings-tabs'),
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.sports_esports),
                          label: Text('Gameplay'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.palette_outlined),
                          label: Text('Appearance'),
                        ),
                        ButtonSegment(
                          value: 2,
                          icon: Icon(Icons.volume_up_outlined),
                          label: Text('Audio'),
                        ),
                      ],
                      selected: {_settingsTab},
                      showSelectedIcon: false,
                      onSelectionChanged: (selected) {
                        _update(() => _settingsTab = selected.first);
                      },
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _settingsPanel(
                        BallWarsColors.of(context),
                        _settingsTab,
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('match-settings-all-set'),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('All set'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } finally {
      _refreshDrawer = null;
    }
  }

  Widget _footer(BallWarsColors c) {
    final pickups = _powerUps == null
        ? 'all pickups'
        : '${_powerUps!.where((kind) => !kind.isTrap).length} pickups';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The kind of match: the thread game, weapons only, or both.
          if (widget.initialMode == null)
            SegmentedButton<MatchMode>(
              segments: [
                for (final m in MatchMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (v) async {
                GameAudio.instance.click();
                _update(() {
                  _modePowerUps[_activeProfileId] = _powerUps;
                  _mode = v.first;
                  if (_mode != MatchMode.arsenal) _mayhem = false;
                  _powerUps = _modePowerUps[_activeProfileId];
                  if (_selected.length > _maxBalls) {
                    final keep = _selected.entries.take(_maxBalls).toList();
                    _selected
                      ..clear()
                      ..addEntries(keep);
                  }
                });
                DevicePrefs.write('mode', v.first.id);
                await _loadPrefs();
              },
            ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              dense: true,
              title: const Text('Edit match settings'),
              subtitle: Text(
                [
                  _winsNeeded == 1 ? '1 round' : 'First to $_winsNeeded',
                  '${_speedMultiplier}x',
                  _ballSize.label,
                  'Effects ${_showEffects ? "on" : "off"}',
                  'Finishers ${_finishersOn ? "on" : "off"}',
                  if (_mode != MatchMode.threads) pickups,
                  if (_dualWield && _mode != MatchMode.threads) 'Dual wield',
                  if (_mayhem) 'Mayhem',
                  if (_endlessBattle && !_mayhem && _mode == MatchMode.arsenal)
                    'Endless',
                  if (_shrinkingArena) 'Shrinking arena',
                ].join(' / '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.tune),
              onTap: _openSettings,
            ),
          ),
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
                          _mayhem
                              ? 'Pick exactly 6 balls'
                              : 'Pick 2 to 4 balls',
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
          const SizedBox(height: 6),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _categoryBalls.length >= 2 ? _randomMatchup : null,
                icon: const Icon(Icons.shuffle),
                label: const Text('Random'),
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

  bool get _useSettingCards => _settingCards;

  Widget _choice<T>(
    IconData icon,
    String title,
    List<T> values,
    T value,
    String Function(T) label,
    void Function(T) change, {
    String? tooltip,
  }) {
    final next = values[(values.indexOf(value) + 1) % values.length];
    final tile = InkWell(
      key: ValueKey('setting-$title'),
      onTap: () {
        GameAudio.instance.click();
        change(next);
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _useSettingCards
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.unfold_more, size: 18),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label(value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.unfold_more, size: 18),
                  ],
                ),
        ),
      ),
    );
    return tooltip == null ? tile : Tooltip(message: tooltip, child: tile);
  }

  Widget _settingsGroup(String title, List<Widget> rows) {
    if (!_useSettingCards) {
      // Preserve the existing grouped list layout.
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...rows,
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 600
                  ? 3
                  : bounds.maxWidth >= 280
                  ? 2
                  : 1;
              final width = (bounds.maxWidth - 8 * (columns - 1)) / columns;
              final scale = MediaQuery.textScalerOf(
                context,
              ).scale(1).clamp(1.0, 2.0);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final row in rows)
                    SizedBox(
                      width: width,
                      height: 112 * scale,
                      child: Card(
                        key: const ValueKey('individual-setting-card'),
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: row,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _settingsPanel(BallWarsColors c, int tab) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (tab == 0)
        _settingsGroup('Gameplay', [
          _choice(
            Icons.emoji_events_outlined,
            'Rounds',
            const [1, 2, 3],
            _winsNeeded,
            (v) => v == 1 ? '1 round' : 'First to $v',
            (v) {
              _update(() => _winsNeeded = v);
              _writeProfile('rounds', v);
            },
          ),
          _choice(
            Icons.speed,
            'Speed',
            _speeds,
            _speedMultiplier,
            (v) => '${v == v.roundToDouble() ? v.toInt() : v}×',
            (v) {
              _update(() => _speedMultiplier = v);
              _writeProfile('speed', v);
            },
          ),
          _choice(
            Icons.trending_up,
            'Automatic speed-up',
            const [true, false],
            _automaticSpeedUp,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _automaticSpeedUp = v);
              _writeProfile('automatic-speed-up', v ? '1' : '0');
            },
          ),
          if (_mode != MatchMode.threads) ...[
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(
                _powerUps == null
                    ? 'Pickups: All'
                    : 'Pickups: ${_powerUps!.where((kind) => !kind.isTrap).length} of ${PowerUpKind.values.where((kind) => !kind.isTrap).length}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseWeapons,
            ),
            _choice(
              Icons.pan_tool_alt,
              'Dual wield',
              const [false, true],
              _dualWield,
              (v) => v ? 'On' : 'Off',
              (v) {
                _update(() => _dualWield = v);
                _writeProfile('dual-wield', v ? '1' : '0');
              },
            ),
            if (_mode == MatchMode.arsenal) ...[
              if (widget.initialMode == null)
                _choice(
                  Icons.whatshot,
                  'Mayhem',
                  const [false, true],
                  _mayhem,
                  (v) => v ? 'On' : 'Off',
                  (v) {
                    _update(() {
                      _mayhem = v;
                      if (v &&
                          !_shown.any((category) => category.id == _category)) {
                        _selected.clear();
                        final first = _shown.firstOrNull;
                        _category = first?.id;
                        _categoryText.text = first?.name ?? '';
                      }
                      if (!v && _selected.length > 4) {
                        final keep = _selected.entries.take(4).toList();
                        _selected
                          ..clear()
                          ..addEntries(keep);
                      }
                    });
                    DevicePrefs.write('mayhem', v ? '1' : '0');
                    _loadPrefs(mayhemOverride: v);
                  },
                ),
              if (_mayhem)
                _choice(
                  Icons.timer,
                  'Match time',
                  const [30, 60, 120, 180, 300, 600],
                  _mayhemSeconds,
                  (v) => v < 60 ? '${v}s' : '${v ~/ 60} min',
                  (v) {
                    _update(() => _mayhemSeconds = v);
                    _writeProfile('mayhem-seconds', v);
                  },
                ),
              if (!_mayhem)
                _choice(
                  Icons.all_inclusive,
                  'Endless Battle',
                  const [false, true],
                  _endlessBattle,
                  (v) => v ? 'On' : 'Off',
                  (v) {
                    _update(() => _endlessBattle = v);
                    _writeProfile('endless-battle', v ? '1' : '0');
                  },
                ),
            ],
          ],
          _choice(
            Icons.zoom_in_map,
            'Shrinking arena',
            const [false, true],
            _shrinkingArena,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _shrinkingArena = v);
              _writeProfile('shrinking-arena', v ? '1' : '0');
            },
          ),
        ]),
      if (tab == 1)
        _settingsGroup('Appearance', [
          _choice(
            Icons.stadium_outlined,
            'Arena',
            ArenaDecoration.values,
            _arenaDecoration ?? AppSettingsScope.of(context).arenaDecoration,
            (v) => v.label,
            (v) {
              _update(() => _arenaDecoration = v);
              _writeProfile('arena-decoration-user', v.name);
            },
          ),
          _choice(
            Icons.auto_fix_high,
            'Effects',
            const [true, false],
            _showEffects,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _showEffects = v);
              _writeProfile('effects', v ? '1' : '0');
            },
          ),
          _choice(
            Icons.circle_outlined,
            'Size',
            BallSize.values,
            _ballSize,
            (v) => v.label,
            (v) {
              _update(() => _ballSize = v);
              _writeProfile('size', v.id);
            },
          ),
          _choice(
            Icons.flare,
            'Wall sparks',
            WallSparkSize.values,
            _wallSparkSize,
            (v) => v.label,
            (v) {
              _update(() => _wallSparkSize = v);
              _writeProfile('wall-spark-size', v.id);
            },
          ),
          _choice(
            Icons.face,
            'Ball look',
            BallLook.values,
            _look,
            (v) => v.name,
            (v) {
              _update(() => _look = v);
              _writeProfile('look', v.name);
            },
            tooltip: 'Ball look: ${_look.name}',
          ),
          _choice(
            Icons.back_hand_outlined,
            'Hands on pictures',
            const [true, false],
            _handsOnPictures,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _handsOnPictures = v);
              _writeProfile('hands-on-pictures', v ? '1' : '0');
            },
          ),
          _choice(
            Icons.circle,
            'White pickup backgrounds',
            const [true, false],
            _whitePickupBackgrounds,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _whitePickupBackgrounds = v);
              _writeProfile('white-pickup-backgrounds', v ? '1' : '0');
            },
          ),
          _choice(
            Icons.movie_outlined,
            'Finishers',
            const [true, false],
            _finishersOn,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _finishersOn = v);
              _writeProfile('finishers', v ? '1' : '0');
            },
          ),
          _choice(
            Icons.content_cut,
            'Random hairstyles',
            const [false, true],
            _randomizedHairstyles,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _randomizedHairstyles = v);
              _writeProfile('randomized-hairstyles', v ? '1' : '0');
            },
          ),
        ]),
      if (tab == 2)
        _settingsGroup('Audio', [
          _choice(
            Icons.music_note,
            'Music',
            const [false, true],
            GameAudio.instance.musicOn,
            (v) => v ? 'On' : 'Off',
            (v) async {
              final saved = GameAudio.instance.setMusicOn(v);
              await saved;
              if (mounted) _update(() {});
            },
          ),
          _choice(
            Icons.volume_up,
            'Sound effects',
            const [false, true],
            GameAudio.instance.effectsOn,
            (v) => v ? 'On' : 'Off',
            (v) async {
              final saved = GameAudio.instance.setEffectsOn(v);
              if (v) GameAudio.instance.click();
              await saved;
              if (mounted) _update(() {});
            },
          ),
          _choice(
            Icons.touch_app,
            'UX sounds',
            const [false, true],
            GameAudio.instance.uxOn,
            (v) => v ? 'On' : 'Off',
            (v) async {
              final saved = GameAudio.instance.setUxOn(v);
              await saved;
              if (mounted) _update(() {});
            },
          ),
        ]),
    ],
  );
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
  final ArenaDecoration arenaDecoration;

  const _WeaponsDialog({
    required this.initial,
    required this.arsenal,
    required this.config,
    required this.arenaDecoration,
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
    List<PowerUpKind> sorted(Iterable<PowerUpKind> kinds) => kinds.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 760),
      title: const Text('Weapons, power-ups & traps'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: [
              if (widget.arsenal)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    crowdNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Pick at least one.'
                          : '$selectedCount selected',
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
              const TabBar(
                tabs: [
                  Tab(text: 'Weapons'),
                  Tab(text: 'Power-ups'),
                  Tab(text: 'Traps'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      child: _cardGrid(sorted(weapons), selectable: true),
                    ),
                    SingleChildScrollView(
                      child: _cardGrid(sorted(powerUps), selectable: true),
                    ),
                    SingleChildScrollView(child: _trapSection(sorted(traps))),
                  ],
                ),
              ),
            ],
          ),
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
      if (widget.arenaDecoration != ArenaDecoration.defaultArena)
        _arenaHazardCard(),
    ],
  );

  Widget _arenaHazardCard() {
    final enabled = widget.config.arenaTrapsEnabled;
    final (name, description, icon, color) = switch (widget.arenaDecoration) {
      ArenaDecoration.space => (
        'Gravity Well',
        'Pulls nearby balls inward at ${widget.config.gravityWellForce.toStringAsFixed(3)} force.',
        Icons.blur_circular,
        const Color(0xFF738BFF),
      ),
      ArenaDecoration.desert => (
        'Quicksand',
        'Slows balls and deals ${widget.config.quicksandDamage.toStringAsFixed(0)} damage per DoT.',
        Icons.blur_on,
        const Color(0xFFD89A52),
      ),
      ArenaDecoration.wilderness => (
        'Vine Snare',
        'Roots a caught ball for ${(widget.config.vineSnareSteps / 60).toStringAsFixed(1)} seconds.',
        Icons.grass,
        const Color(0xFF58A85F),
      ),
      ArenaDecoration.neonGrid => (
        'Laser Gate',
        'A rotating gate deals ${widget.config.laserGateDamage.toStringAsFixed(0)} damage per crossing.',
        Icons.horizontal_rule,
        const Color(0xFF00E5FF),
      ),
      ArenaDecoration.chaotic => (
        'All Arena Traps',
        'Gravity Well, Quicksand, Vine Snare, and Laser Gate deploy together.',
        Icons.cyclone,
        const Color(0xFFFF4FD8),
      ),
      ArenaDecoration.defaultArena => throw StateError('No extra arena trap'),
    };
    final appColors = BallWarsColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Card(
        key: const ValueKey('arena-theme-trap-card'),
        margin: EdgeInsets.zero,
        color: appColors.surfaceHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.18),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      '${widget.arenaDecoration.label} arena trap - ${enabled ? "automatic" : "disabled by admin"}',
                      style: TextStyle(fontSize: 10, color: appColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: appColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.lock_outline_rounded, size: 22),
            ],
          ),
        ),
      ),
    );
  }

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
                    height: 132,
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
                    PowerUpName(
                      kind,
                      tuning: widget.config,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (widget.config.rarityOf(kind) != null)
                      Text(
                        widget.config.rarityOf(kind)!.label,
                        style: TextStyle(fontSize: 10, color: appColors.muted),
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
