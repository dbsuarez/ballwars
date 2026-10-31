import '../../../core/sprites/visual_quality.dart';
import 'dart:math' as math;
import 'dart:convert';
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
import '../domain/arena_rotation.dart';
import 'arena_geometry_editor.dart';
import '../domain/pickup_count.dart';
import '../domain/rarity_preset.dart';
import 'rarity_preset_panel.dart';
import 'loadout_presets_dialog.dart';
import '../domain/loadout_preset.dart';
import '../../arena_simulation/presentation/arena_selection_dialog.dart';

/// Pick 2-4 balls from the built-in packs (Streaming, Countries, ...) or
/// your own groups, mixing categories freely, then start the battle.
/// How many [PowerUpKind]s existed before the weapons pref stored its count
/// (`pref:power-ups-count-<profile>`): the count before Shadow Clone.
const int legacyPowerUpPrefCount = 48;

/// `pref:power-ups-<profile>` for [kinds]: '' means every kind (null), so kinds added later start on.
@visibleForTesting
String powerUpsPref(Set<PowerUpKind>? kinds) =>
    kinds == null ? '' : [for (final k in kinds) k.name].join(',');

/// The weapons choice saved as [saved] when [savedCount] kinds existed (null: before the count was
/// stored, [legacyPowerUpPrefCount]). Null (every kind) when nothing is saved, for '' and for a set
/// holding all of the first [savedCount] kinds, so kinds added since then are on. A set missing one of
/// them stays explicit (kinds added later are then off). Traps are always on.
@visibleForTesting
Set<PowerUpKind>? powerUpsFromPref(String? saved, int? savedCount) {
  final kinds = {
    for (final name in (saved ?? '').split(','))
      ...PowerUpKind.values.where((kind) => kind.name == name),
  };
  final count = (savedCount ?? legacyPowerUpPrefCount).clamp(
    1,
    PowerUpKind.values.length,
  );
  final pickups = kinds.where((kind) => !kind.isTrap).toSet();
  final knewAll = PowerUpKind.values
      .take(count)
      .where((kind) => !kind.isTrap)
      .every(pickups.contains);
  if (kinds.isEmpty || knewAll) return null;
  return {...pickups, ...PowerUpKind.values.where((kind) => kind.isTrap)};
}

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
  EffectRenderMode? _effectRenderMode;
  RarityPreset _rarityPreset = RarityPreset.balanced;
  List<String>? _customRarityDraft;
  int _rarityGeneration = 0;

  List<String> get _customRarityValues =>
      _customRarityDraft ??
      [
        for (final weight in RarityWeights.fromTuning(
          AppSettingsScope.of(context).powerUps,
        ).values)
          weight.toString(),
      ];

  RarityWeights? get _rarityWeights {
    final custom = RarityWeights.parse(_customRarityValues);
    if (_rarityPreset == RarityPreset.custom) return custom;
    return _rarityPreset.resolve(custom ?? RarityWeights([40, 30, 20, 10]));
  }

  PowerUpConfig get _matchTuning =>
      _rarityWeights!.applyTo(AppSettingsScope.of(context).powerUps);

  RaritySpawnOdds? get _rarityOdds => _rarityWeights == null
      ? null
      : RaritySpawnOdds.calculate(
          tuning: AppSettingsScope.of(
            context,
          ).skillLibrary.applyTo(_matchTuning),
          library: AppSettingsScope.of(context).skillLibrary,
          builtIns: _powerUps,
          customIds: _customChoice,
        );

  String? get _rarityError {
    if (_mode.isThreadOnly) return null;
    if (_rarityWeights == null) {
      return 'Use weights from 0 to 100, with at least one above zero.';
    }
    final odds = _rarityOdds!;
    return odds.hasPickups && !odds.weighted
        ? 'Give at least one enabled pickup tier a weight above zero.'
        : null;
  }

  void _changeRarityWeight(int index, String value) {
    _update(
      () => _customRarityDraft = [..._customRarityValues]..[index] = value,
    );
    if (RarityWeights.parse(_customRarityValues) != null) {
      _writeProfile('rarity-custom', jsonEncode(_customRarityValues));
    }
  }

  void _resetRarityWeights() {
    _update(() {
      _customRarityDraft = ['40', '30', '20', '10'];
      _rarityGeneration++;
    });
    _writeProfile('rarity-custom', jsonEncode(_customRarityValues));
  }

  WallSparkSize _wallSparkSize = WallSparkSize.normal;
  BallSize _ballSize = BallSize.medium;
  MatchMode _mode = MatchMode.threads;
  BallLook _look = BallLook.pictures;
  bool _handsOnPictures = false;
  bool _showHpBars = false;
  bool _whitePickupBackgrounds = true;
  bool _randomizedHairstyles = false;

  /// Power-up modes: the chosen power-ups, null for all.
  Set<PowerUpKind>? _powerUps;
  final Map<String, Set<PowerUpKind>?> _modePowerUps = {};

  /// Custom skills switched off in the Weapons dialog (ids), per match type like the built-in choice
  /// (`pref:custom-skills-off-<profile>`). Stored as the ones that are off, so skills made later start on.
  final Map<String, Set<String>> _modeCustomOff = {};
  Set<String> get _customOff => _modeCustomOff[_activeProfileId] ?? const {};

  /// Active custom skills that can spawn as pickups or weapons (same rule as the match's spawner).
  List<SkillDefinition> get _spawnableCustom => [
    for (final skill in AppSettingsScope.of(context).skillLibrary.custom)
      if (skill.spawnsInArena) skill,
  ];

  /// The custom skills a match may spawn: null for all of them.
  Set<String>? get _customChoice {
    final ids = {for (final skill in _spawnableCustom) skill.id};
    if (ids.intersection(_customOff).isEmpty) return null;
    return ids.difference(_customOff);
  }

  /// The pickups on and the pickups there are: built-in non-trap kinds plus spawnable custom skills.
  /// One place for the dialog, the Pickups row and the footer, so they always agree.
  (int, int) _pickupCounts() {
    final custom = _spawnableCustom;
    final customOn = custom.where((s) => !_customOff.contains(s.id)).length;
    return pickupCount(
      _powerUps ?? PowerUpKind.values,
      customOn,
      custom.length,
    );
  }

  /// "Pickups: All", or "Pickups: n of m" counting the built-in pickups and the spawnable custom
  /// skills that are on (traps excluded), the same number the Weapons dialog shows.
  String _pickupsLabel() {
    final (on, total) = _pickupCounts();
    return on == total ? 'Pickups: All' : 'Pickups: $on of $total';
  }

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
  ArenaShape _arenaShape = ArenaShape.circle;
  bool _rotateThemes = false;
  bool _rotateShapes = false;
  int _rotationInterval = 60;
  CenterObstacle _centerObstacle = CenterObstacle.none;
  double _centerObstacleScale = 0.22;
  ArenaDecoration? _arenaDecoration;
  bool _finishersOn = true;
  bool _settingCards = true;
  int _settingsTab = 0;

  /// Which kind of categories the dropdown lists; remembered per device.
  _CategoryFilter _filter = _CategoryFilter.defaults;
  int _winsNeeded = 1;
  int _threadGrowthMaxThreads = 180;
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
    final rememberedShape = ArenaShape.byName(await DevicePrefs.read('arena-shape'));
    _arenaShape = rememberedShape ?? ArenaShape.circle;
    _rotateThemes = await DevicePrefs.read('arena-rotate-themes') == '1';
    _rotateShapes = await DevicePrefs.read('arena-rotate-shapes') == '1';
    _rotationInterval = int.tryParse(await DevicePrefs.read('arena-rotation-interval') ?? '') ?? 60;
    _centerObstacle = CenterObstacle.byName(
          await DevicePrefs.read('center-obstacle')) ?? CenterObstacle.none;
    _centerObstacleScale = double.tryParse(
          await DevicePrefs.read('center-obstacle-scale') ?? '') ?? 0.22;
    final profileMode =
        widget.initialMode ?? rememberedMode ?? MatchMode.threads;
    final profileMayhem =
        mayhemOverride ??
        (widget.initialMode != null
            ? widget.initialMayhem && profileMode == MatchMode.arsenal
            : (profileMode == MatchMode.arsenal &&
                  await DevicePrefs.read('mayhem') == '1'));
    final rarityName = await _readProfile(
      profileMode,
      'rarity-preset',
      mayhem: profileMayhem,
    );
    final rarityCustom = await _readProfile(
      profileMode,
      'rarity-custom',
      mayhem: profileMayhem,
    );
    List<String>? customRarity;
    try {
      final decoded = jsonDecode(rarityCustom ?? 'null');
      if (decoded is List && decoded.length == 4) {
        final strings = decoded.map((v) => '$v').toList();
        if (RarityWeights.parse(strings) != null) customRarity = strings;
      }
    } on FormatException {
      /* Invalid old preferences fall back to admin seeds. */
    }
    final effectVisuals = await _readProfile(
      profileMode,
      'effect-visuals',
      mayhem: profileMayhem,
    );
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
    final growthLimit = int.tryParse(
      await _readProfile(profileMode, 'growth-max-threads', mayhem: profileMayhem) ?? '',
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
    final hpBars = await _readProfile(
      profileMode,
      'hp-bars',
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
      final savedCount = int.tryParse(
        await DevicePrefs.read('power-ups-count-$profileId') ?? '',
      );
      _modePowerUps[profileId] = powerUpsFromPref(saved, savedCount);
    }
    for (final profileId in profileIds) {
      final off = await DevicePrefs.read('custom-skills-off-$profileId');
      _modeCustomOff[profileId] = {
        for (final id in (off ?? '').split(','))
          if (id.isNotEmpty) id,
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
      _showHpBars = hpBars == '1';
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
      _rarityPreset =
          RarityPreset.values
              .where((preset) => preset.name == rarityName)
              .firstOrNull ??
          RarityPreset.balanced;
      _customRarityDraft = customRarity;
      _rarityGeneration++;
      _effectRenderMode = EffectRenderMode.values
          .where((mode) => mode.name == effectVisuals)
          .firstOrNull;
      _finishersOn = finishers != '0';
      _settingCards = settingCards;
      _wallSparkSize = wallSparkSize ?? WallSparkSize.normal;
      _winsNeeded = const [1, 2, 3].contains(rounds) ? rounds! : 1;
      _threadGrowthMaxThreads =
          const [5, 10, 20, 40, 80, 180].contains(growthLimit)
          ? growthLimit!
          : 180;
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
    final spawnable = _spawnableCustom;
    final choice = await showDialog<_WeaponChoice>(
      context: context,
      builder: (_) => _WeaponsDialog(
        skillLibrary: AppSettingsScope.of(context).skillLibrary,
        customSkills: spawnable,
        initialCustom: {
          for (final skill in spawnable)
            if (!_customOff.contains(skill.id)) skill.id,
        },
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
    if (choice == null || !mounted) return;
    final chosen = choice.kinds;
    final all = chosen.length == PowerUpKind.values.length;
    _update(() {
      _powerUps = all ? null : chosen;
      _modeCustomOff[_activeProfileId] = {
        ..._customOff.where((id) => !spawnable.any((s) => s.id == id)),
        for (final skill in spawnable)
          if (!choice.custom.contains(skill.id)) skill.id,
      };
    });
    DevicePrefs.write(
      'custom-skills-off-$_activeProfileId',
      _customOff.join(','),
    );
    _modePowerUps[_activeProfileId] = _powerUps;
    DevicePrefs.write('power-ups-$_activeProfileId', powerUpsPref(_powerUps));
    DevicePrefs.write(
      'power-ups-count-$_activeProfileId',
      PowerUpKind.values.length,
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

  bool get _canStart =>
      _rarityError == null &&
      (_mayhem
          ? _selected.length == 6
          : _selected.length >= 2 && _selected.length <= _maxBalls);

  Future<void> _chooseArena() async {
    final picked = await showArenaSelectionDialog(
      context,
      selected:
          _arenaDecoration ?? AppSettingsScope.of(context).arenaDecoration,
    );
    if (picked == null || !mounted) return;
    _update(() => _arenaDecoration = picked);
    _writeProfile('arena-decoration-user', picked.name);
  }

  void _start() {
    if (!_canStart) return;
    GameAudio.instance.click();
    widget.onStartBattle(
      MatchConfig(
        simulationRevision: _centerObstacle != CenterObstacle.none ? 6 : (_arenaShape == ArenaShape.square ? 5 : 4),
        contestants: _selected.values.toList(),
        speedMultiplier: _speedMultiplier,
        automaticSpeedUp: _automaticSpeedUp,
        showEffects: _showEffects,
        effectRenderMode: _effectRenderMode,
        ballGlowWidth: AppSettingsScope.of(context).ballGlowWidth,
        bloodColor: AppSettingsScope.of(context).bloodColor,
        wallSparkSize: _wallSparkSize,
        winsNeeded: _winsNeeded,
        ballSize: _mayhem ? BallSize.small : _ballSize,
        mode: _mayhem ? MatchMode.arsenal : _mode,
        threadGrowthMaxThreads: _threadGrowthMaxThreads,
        finishersEnabled: _finishersOn,
        look: _look,
        handsOnPictures: _handsOnPictures,
        showHpBars: _showHpBars,
        whitePickupBackgrounds: _whitePickupBackgrounds,
        randomizedHairstyles: _randomizedHairstyles,
        powerUps: _mode.isThreadOnly ? null : _powerUps,
        customSkills: _mode.isThreadOnly ? null : _customChoice,
        dualWield: !_mode.isThreadOnly && _dualWield,
        endlessBattle:
            _mode == MatchMode.arsenal && (_endlessBattle || _mayhem),
        mayhem: _mode == MatchMode.arsenal && _mayhem,
        mayhemSeconds: _mayhemSeconds,
        shrinkingArena: _shrinkingArena,
        arenaShape: _arenaShape,
        arenaRotation: ArenaRotation(rotateThemes: _rotateThemes, rotateShapes: _rotateShapes, intervalSeconds: _rotationInterval),
        centerObstacle: _centerObstacle,
        centerObstacleScale: _centerObstacleScale,
        minimumArenaScale: AppSettingsScope.of(context).minimumArenaScale,
        arenaDecoration:
            _arenaDecoration ?? AppSettingsScope.of(context).arenaDecoration,
        // The admin's power-up numbers; part of the match (and of its replay link).
        tuning: _mode.isThreadOnly
            ? PowerUpConfig.defaults
            : _matchTuning,
        skillLibrary: _mode.isThreadOnly
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
                        // No Audio tab: music, sound effects and UX sounds are switched in the arena.
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
    final (pickupsOn, pickupsTotal) = _pickupCounts();
    final pickups = pickupsOn == pickupsTotal
        ? 'all pickups'
        : '$pickupsOn pickups';
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
                  if (!_mode.isThreadOnly) pickups,
                  if (_dualWield && !_mode.isThreadOnly) 'Dual wield',
                  if (_mayhem) 'Mayhem',
                  if (_endlessBattle && !_mayhem && _mode == MatchMode.arsenal)
                    'Endless',
                  if (_mode == MatchMode.threadGrowth)
                    'Max $_threadGrowthMaxThreads threads',
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
          if (_rarityError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _rarityError!,
                key: const ValueKey('match-rarity-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
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
    VoidCallback? onTap,
  }) {
    final next = values[(values.indexOf(value) + 1) % values.length];
    final tile = InkWell(
      key: ValueKey('setting-$title'),
      onTap: () {
        GameAudio.instance.click();
        if (onTap != null) {
          onTap();
        } else {
          change(next);
        }
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
          if (_mode == MatchMode.threadGrowth)
            _choice(
              Icons.linear_scale,
              'Maximum threads per ball',
              const [5, 10, 20, 40, 80, 180],
              _threadGrowthMaxThreads,
              (v) => '$v',
              (v) {
                _update(() => _threadGrowthMaxThreads = v);
                _writeProfile('growth-max-threads', v);
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
          if (!_mode.isThreadOnly) ...[
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(_pickupsLabel()),
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
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Arena geometry editor'),
            subtitle: const Text('Preview and edit outer shape and central obstacle'),
            onTap: () async {
              final selection = await showArenaGeometryEditor(context,
                  shape: _arenaShape, obstacle: _centerObstacle,
                  scale: _centerObstacleScale);
              if (selection == null || !mounted) return;
              _update(() {
                _arenaShape = selection.shape;
                _centerObstacle = selection.obstacle;
                _centerObstacleScale = selection.scale;
              });
              DevicePrefs.write('arena-shape', selection.shape.name);
              DevicePrefs.write('center-obstacle', selection.obstacle.name);
              DevicePrefs.write('center-obstacle-scale', selection.scale.toString());
            },
          ),
          _choice(
            Icons.crop_square,
            'Arena shape',
            ArenaShape.values,
            _arenaShape,
            (shape) => shape.label,
            (shape) {
              _update(() => _arenaShape = shape);
              DevicePrefs.write('arena-shape', shape.name);
            },
          ),
          _choice(
            Icons.palette,
            'Rotate arena themes',
            const [false, true],
            _rotateThemes,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _rotateThemes = v);
              DevicePrefs.write('arena-rotate-themes', v ? '1' : '0');
            },
          ),
          _choice(
            Icons.sync,
            'Rotate circle / square',
            const [false, true],
            _rotateShapes,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _rotateShapes = v);
              DevicePrefs.write('arena-rotate-shapes', v ? '1' : '0');
            },
          ),
          if (_rotateThemes || _rotateShapes)
            _choice(
              Icons.timer_outlined,
              'Arena rotation interval',
              const [30, 60, 90, 120, 180, 300],
              _rotationInterval,
              (v) => '${v}s',
              (v) {
                _update(() => _rotationInterval = v);
                DevicePrefs.write('arena-rotation-interval', v);
              },
            ),
          _choice(
            Icons.adjust,
            'Center obstacle',
            CenterObstacle.values,
            _centerObstacle,
            (obstacle) => obstacle.label,
            (obstacle) {
              _update(() => _centerObstacle = obstacle);
              DevicePrefs.write('center-obstacle', obstacle.name);
            },
          ),
          if (_centerObstacle != CenterObstacle.none)
            _choice(
              Icons.aspect_ratio,
              'Obstacle size',
              const [0.12, 0.18, 0.22, 0.28, 0.34],
              _centerObstacleScale,
              (size) => '${(size * 100).round()}%',
              (size) {
                _update(() => _centerObstacleScale = size);
                DevicePrefs.write('center-obstacle-scale', size.toString());
              },
            ),
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
      if (tab == 0 && !_mode.isThreadOnly)
        RarityPresetPanel(
          key: ValueKey('rarity-panel-$_activeProfileId-$_rarityGeneration'),
          preset: _rarityPreset,
          customValues: _customRarityValues,
          onPreset: (preset) {
            _update(() => _rarityPreset = preset);
            _writeProfile('rarity-preset', preset.name);
          },
          onWeight: _changeRarityWeight,
          onReset: _resetRarityWeights,
          odds: _rarityOdds,
          error: _rarityError,
          trapStartSeconds:
              AppSettingsScope.of(context).powerUps.trapStartSteps / 60,
        ),
      if (tab == 1)
        _settingsGroup('Appearance', [
          const VisualQualityControl(),
          _choice<EffectRenderMode?>(
            Icons.auto_awesome,
            'Effect visuals',
            [null, ...EffectRenderMode.values],
            _effectRenderMode,
            (mode) => mode?.label ?? 'Default',
            (mode) {
              _update(() => _effectRenderMode = mode);
              _writeProfile('effect-visuals', mode?.name ?? 'default');
            },
          ),
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
            onTap: _chooseArena,
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
            Icons.health_and_safety_outlined,
            'HP bars',
            const [false, true],
            _showHpBars,
            (v) => v ? 'On' : 'Off',
            (v) {
              _update(() => _showHpBars = v);
              _writeProfile('hp-bars', v ? '1' : '0');
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
/// What the Weapons dialog returns: the built-ins and the custom skills (ids) that are on.
class _WeaponChoice {
  const _WeaponChoice(this.kinds, this.custom);
  final Set<PowerUpKind> kinds;
  final Set<String> custom;
}

class _WeaponsDialog extends StatefulWidget {
  final Set<PowerUpKind> initial;

  /// Active custom skills that can spawn, listed next to the built-ins, and the ones that start on.
  final List<SkillDefinition> customSkills;
  final Set<String> initialCustom;

  /// The admin's skill library: a built-in's own description (Skill Management) replaces the
  /// generated text on its card.
  final SkillLibrary skillLibrary;
  final bool arsenal;
  final PowerUpConfig config;
  final ArenaDecoration arenaDecoration;

  const _WeaponsDialog({
    required this.initial,
    this.customSkills = const [],
    this.initialCustom = const {},
    this.skillLibrary = SkillLibrary.defaults,
    required this.arsenal,
    required this.config,
    required this.arenaDecoration,
  });

  @override
  State<_WeaponsDialog> createState() => _WeaponsDialogState();
}

class _WeaponsDialogState extends State<_WeaponsDialog> {
  late final Set<PowerUpKind> _on = {...widget.initial};
  late final Set<String> _customOn = {...widget.initialCustom};

  Future<void> _presets() async {
    final preset = await showDialog<LoadoutPreset>(
      context: context,
      builder: (_) => LoadoutPresetsDialog(
        currentKinds: {..._on},
        currentCustomIds: {..._customOn},
        availableCustomNames: {
          for (final skill in widget.customSkills) skill.id: skill.name,
        },
      ),
    );
    if (!mounted || preset == null) return;
    setState(() {
      _on
        ..clear()
        ..addAll(PowerUpKind.values.where((kind) => kind.isTrap))
        ..addAll(preset.kinds);
      _customOn
        ..clear()
        ..addAll(
          preset.customIds.where(
            (id) => widget.customSkills.any((skill) => skill.id == id),
          ),
        );
    });
  }

  List<SkillDefinition> _customIn(bool Function(SkillCategory category) test) =>
      widget.customSkills
          .where((skill) => test(skill.resolvedCategory))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Widget build(BuildContext context) {
    final weapons = PowerUpKind.values.where((kind) => kind.isWeapon);
    final powerUps = PowerUpKind.values.where((kind) => kind.isPowerUp);
    final traps = PowerUpKind.values.where((kind) => kind.isTrap);
    final selectable = PowerUpKind.values.where((kind) => !kind.isTrap);
    final selectedCount = pickupCount(_on, _customOn.length, 0).$1;
    final customWeapons = _customIn((c) => c == SkillCategory.weapon);
    final customTraps = _customIn(
      (c) => c == SkillCategory.trap || c == SkillCategory.arenaTrap,
    );
    final customPowerUps = _customIn(
      (c) =>
          c != SkillCategory.weapon &&
          c != SkillCategory.trap &&
          c != SkillCategory.arenaTrap,
    );
    List<PowerUpKind> sorted(Iterable<PowerUpKind> kinds) => kinds.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 1080),
      title: const Text('Weapons, power-ups & traps'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 1040,
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('loadout-presets'),
                  onPressed: _presets,
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: const Text('Loadout presets'),
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
                    onPressed: () => setState(() {
                      _on.addAll(selectable);
                      _customOn.addAll(widget.customSkills.map((s) => s.id));
                    }),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _on.removeAll(selectable);
                      _customOn.clear();
                    }),
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
                      child: Column(
                        children: [
                          _cardGrid(sorted(weapons), selectable: true),
                          ..._customSection(customWeapons),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _cardGrid(sorted(powerUps), selectable: true),
                          ..._customSection(customPowerUps),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _trapSection(sorted(traps)),
                          ..._customSection(customTraps),
                        ],
                      ),
                    ),
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
              : () => Navigator.of(context).pop(_WeaponChoice(_on, _customOn)),
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

  /// Your custom skills in this tab, each switched on or off on its own.
  List<Widget> _customSection(List<SkillDefinition> skills) {
    if (skills.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Your custom skills',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final skill in skills)
                  SizedBox(
                    width: width - (columns == 1 ? 16 : 8),
                    height: 100,
                    child: _customCard(skill),
                  ),
              ],
            ),
          );
        },
      ),
    ];
  }

  Widget _customCard(SkillDefinition skill) {
    final selected = _customOn.contains(skill.id);
    final colors = Theme.of(context).colorScheme;
    final appColors = BallWarsColors.of(context);
    // Its own tier (a custom skill's tier never follows the built-in once set).
    final rarity = SkillLibrary.rarityOf(skill, widget.config);
    final fires = skill.payloadSkillId;
    final firedName = fires == null
        ? null
        : widget.customSkills.where((s) => s.id == fires).firstOrNull?.name ??
              (fires.startsWith('builtin.')
                  ? PowerUpKind.values
                        .where((k) => k.name == fires.substring(8))
                        .firstOrNull
                        ?.label
                  : null);
    final details = [
      'Custom ${skill.resolvedCategory == SkillCategory.weapon ? 'weapon' : 'skill'} based on ${skill.baseKind.label}',
      if (skill.artworkKind != null) 'looks like ${skill.artworkKind!.label}',
      if (firedName != null) 'fires ${skill.projectileCount ?? 1} x $firedName',
    ].join(', ');
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
        key: ValueKey('selection-card-${skill.id}'),
        onTap: () => setState(
          () => selected ? _customOn.remove(skill.id) : _customOn.add(skill.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PowerUpIcon(
                skill.displayKind,
                size: 40,
                tint: skill.spriteTint,
                spriteId: skill.iconSpriteId,
                useSettingsArtwork: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PowerUpName(
                      skill.baseKind,
                      tuning: widget.config,
                      label: skill.name,
                      rarity: rarity,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (rarity != null)
                      Text(
                        rarity.label,
                        style: TextStyle(fontSize: 10, color: appColors.muted),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      skill.description.isNotEmpty
                          ? skill.description
                          : '$details.',
                      maxLines: 2,
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
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22,
                color: selected ? colors.primary : colors.outline,
              ),
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
          final columns = constraints.maxWidth >= 900
              ? 3
              : constraints.maxWidth >= 560
              ? 2
              : 1;
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
                    height: 100,
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
                      switch (widget.skillLibrary
                          .builtIn(kind, widget.config)
                          .description) {
                        '' => powerUpDescription(
                          kind,
                          arsenal: widget.arsenal,
                          config: widget.config,
                        ),
                        final own => own,
                      },
                      maxLines: 2,
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
