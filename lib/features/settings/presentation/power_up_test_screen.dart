import '../../../core/theme/game_ui.dart';
import '../../arena_simulation/domain/simulation_ball.dart';
import '../../arenas/domain/arena_definition.dart';
import 'dart:math' as math;

import '../../../core/audio/game_audio.dart';
import '../../../core/audio/audio_channel_button.dart';
import '../../../core/offline/device_prefs.dart';
import '../../arena_simulation/presentation/finisher_profile.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../../core/widgets/screen_awake.dart';
import '../../../core/widgets/canvas_action_glyph.dart';
import '../../../core/widgets/animated_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_canvas.dart';
import '../../arena_simulation/presentation/arena_selection_dialog.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import 'app_settings_scope.dart';
import '../domain/app_settings.dart';

/// Runs actual matches with local, admin-only scenario controls.
class PowerUpTestScreen extends StatefulWidget {
  const PowerUpTestScreen({
    super.key,
    this.initialSkill,
    this.initialLibrary,
    this.initialArena,
  });

  /// An unsaved editor draft to inject into this test session only.
  final SkillDefinition? initialSkill;
  final SkillLibrary? initialLibrary;
  final ArenaDefinition? initialArena;

  @override
  State<PowerUpTestScreen> createState() => _PowerUpTestScreenState();
}

enum _TestMotion { moving, idle, randomStart }

class _PowerUpTestScreenState extends State<PowerUpTestScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _balls = [
    CustomBall(
      id: 'test-a',
      name: 'Ball A',
      primaryColor: Color(0xFFFF5B4D),
      glowColor: Color(0xFFFFA38F),
    ),
    CustomBall(
      id: 'test-b',
      name: 'Ball B',
      primaryColor: Color(0xFF4D9DFF),
      glowColor: Color(0xFF7EDBFF),
    ),
  ];
  late final Ticker _ticker;
  Duration? _previous;
  bool _checking = false;
  bool? _allowed;
  MatchSimulationController? _match;
  bool _paused = true;
  SimulationBall? _dragBall;
  bool _foreground = true;
  bool _randomSpawns = false;
  bool _endless = true;
  GameAudio get _audio => GameAudio.instance;
  (int, int, int, int, int, int) _heardPowerUps = (0, 0, 0, 0, 0, 0);
  int _heardGatling = 0;
  int _heardWallHits = 0;
  int _heardBallHits = 0;
  double _speed = 1;
  MatchMode _mode = MatchMode.arsenal;
  ArenaShape _arenaShape = ArenaShape.circle;

  /// The arena picked in the bottom bar; null follows the admin's setting.
  ArenaDecoration? _arenaChoice;
  String? _arenaPresetId;
  late ArenaDefinition? _arenaDraft = widget.initialArena;
  ArenaDefinition? get _selectedArena =>
      _arenaDraft ??
      AppSettingsScope.of(context).arenaCatalog.find(
        _arenaPresetId ?? AppSettingsScope.of(context).arenaCatalog.defaultId,
      );

  String _layout = 'Separated';
  final _motion = [_TestMotion.moving, _TestMotion.moving];
  final _collapsedRails = [false, false];
  final _randomStart = math.Random();
  final _items = [PowerUpKind.pistol, PowerUpKind.shield];
  final List<PowerUpKind?> _savedItems = [PowerUpKind.pistol, null];
  final List<PowerUpKind?> _secondaryWeapons = [null, PowerUpKind.shield];
  final List<PowerUpKind?> _powerUps = [null, null];
  final List<PowerUpKind?> _arenaTraps = [
    ...PowerUpKind.values.where((kind) => kind.isTrap).take(3),
  ];
  final _pickerTabs = [0, 0];
  final _skillIds = List.generate(2, (_) => List<String?>.filled(3, null));
  final _trapSkillIds = List<String?>.filled(3, null);
  bool _missingRememberedSkill = false;
  SkillDefinition? _selection(PowerUpKind? kind, String? id) => kind == null
      ? null
      : id == null
      ? _match!.skillLibrary.builtIn(kind, _match!.tuning)
      : _match!.skillLibrary.byId(id, _match!.tuning);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      allowed =
          await AppSettingsScope.maybeScope(context)?.adminAuth?.isAdmin() ??
          false;
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    if (allowed) await _loadRememberedChoices();
    final initialSkill = widget.initialSkill;
    if (allowed && initialSkill != null) {
      final category = initialSkill.resolvedCategory;
      if (category == SkillCategory.weapon) {
        _items[0] = initialSkill.baseKind;
        _savedItems[0] = initialSkill.baseKind;
        _skillIds[0][0] = initialSkill.id;
        _pickerTabs[0] = 0;
      } else if (category == SkillCategory.powerUp) {
        _powerUps[0] = initialSkill.baseKind;
        _skillIds[0][2] = initialSkill.id;
        _pickerTabs[0] = 1;
      } else {
        _arenaTraps[0] = initialSkill.baseKind;
        _trapSkillIds[0] = initialSkill.id;
        _pickerTabs[0] = 2;
      }
    }
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      if (allowed) {
        _audio.stopMenuMusic();
        _reset();
      }
    });
    if (allowed && _missingRememberedSkill && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some remembered skills are no longer available. Their test slots were cleared.',
          ),
        ),
      );
    }
  }

  Future<void> _loadRememberedChoices() async {
    final settings = AppSettingsScope.of(context);
    final library = widget.initialSkill == null
        ? (widget.initialLibrary ?? settings.skillLibrary)
        : (widget.initialLibrary ?? settings.skillLibrary).withDefinition(
            widget.initialSkill!,
            settings.powerUps,
          );
    for (var i = 0; i < 2; i++) {
      _collapsedRails[i] =
          await DevicePrefs.read('power-test-rail-$i-collapsed') == '1';
    }
    _arenaPresetId = await DevicePrefs.read('power-test-arena-preset');
    final savedShape = await DevicePrefs.read('power-test-arena-shape');
    _arenaShape =
        ArenaShape.values
            .where((shape) => shape.name == savedShape)
            .firstOrNull ??
        _selectedArena?.shape ??
        ArenaShape.circle;
    final savedArena = await DevicePrefs.read('power-test-arena');
    _arenaChoice = ArenaDecoration.values
        .where((d) => d.name == savedArena)
        .firstOrNull;
    if (_arenaDraft case final arena?) {
      _arenaPresetId = arena.id;
      _arenaChoice = arena.trapTheme;
      _arenaShape = arena.shape;
    }
    for (var i = 0; i < 2; i++) {
      final raw = await DevicePrefs.read('power-test-item-$i');
      final remembered = PowerUpKind.values
          .where((kind) => kind.name == raw)
          .firstOrNull;
      if (remembered != null) {
        _items[i] = remembered;
        _savedItems[i] = remembered;
      } else if (raw == 'none') {
        _savedItems[i] = null;
      }
      final tab = int.tryParse(
        await DevicePrefs.read('power-test-item-tab-$i') ?? '',
      );
      if (tab != null && tab >= 0 && tab < 3) _pickerTabs[i] = tab;
      _secondaryWeapons[i] = _rememberedKind(
        await DevicePrefs.read('power-test-secondary-$i'),
      );
      _powerUps[i] = _rememberedKind(
        await DevicePrefs.read('power-test-power-$i'),
      );
      for (var slot = 0; slot < 3; slot++) {
        final key = const ['item', 'secondary', 'power'][slot];
        final id = await DevicePrefs.read('power-test-$key-$i-skill-id');
        if (id == null || id == 'none') continue;
        final skill = library.byId(id, settings.powerUps);
        if (skill != null &&
            skill.resolvedCategory ==
                (slot == 2 ? SkillCategory.powerUp : SkillCategory.weapon)) {
          _skillIds[i][slot] = id;
          if (slot == 0) _savedItems[i] = skill.baseKind;
          if (slot == 1) _secondaryWeapons[i] = skill.baseKind;
          if (slot == 2) _powerUps[i] = skill.baseKind;
        } else {
          _missingRememberedSkill = true;
          if (slot == 0) _savedItems[i] = null;
          if (slot == 1) _secondaryWeapons[i] = null;
          if (slot == 2) _powerUps[i] = null;
        }
      }
    }
    for (var i = 0; i < _arenaTraps.length; i++) {
      final saved = await DevicePrefs.read('power-test-trap-$i');
      if (saved != null) _arenaTraps[i] = _rememberedKind(saved);
      final id = await DevicePrefs.read('power-test-trap-$i-skill-id');
      if (id != null && id != 'none') {
        final skill = library.byId(id, settings.powerUps);
        if (skill != null &&
            (skill.resolvedCategory == SkillCategory.trap ||
                skill.resolvedCategory == SkillCategory.arenaTrap)) {
          _trapSkillIds[i] = id;
          _arenaTraps[i] = skill.baseKind;
        } else {
          _missingRememberedSkill = true;
          _arenaTraps[i] = null;
        }
      }
    }
    // Migrate the original one-slot preference into the first slot.
    final legacyTrap = _rememberedKind(
      await DevicePrefs.read('power-test-trap'),
    );
    if (legacyTrap != null &&
        await DevicePrefs.read('power-test-trap-0') == null) {
      _arenaTraps[0] = legacyTrap;
    }
  }

  PowerUpKind? _rememberedKind(String? raw) =>
      PowerUpKind.values.where((kind) => kind.name == raw).firstOrNull;

  void _reset() {
    _heardPowerUps = (0, 0, 0, 0, 0, 0);
    _heardInteractions.clear();
    _heardCuts = 0;
    _heardKnockouts = 0;
    _heardGatling = 0;
    _heardWallHits = 0;
    _heardBallHits = 0;
    if (_ticker.isActive) _ticker.stop();
    final settings = AppSettingsScope.of(context);
    final initialSkill = widget.initialSkill;
    final skillLibrary = initialSkill == null
        ? (widget.initialLibrary ?? settings.skillLibrary)
        : (widget.initialLibrary ?? settings.skillLibrary).withDefinition(
            initialSkill.copyWith(enabled: true),
            settings.powerUps,
          );
    _match = MatchSimulationController(
      _balls,
      simulationRevision: 10,
      arenaRadius: 200,
      arenaShape: _arenaShape,
      centerObstacle: _selectedArena?.obstacle ?? CenterObstacle.none,
      centerObstacleScale: _selectedArena?.obstacleScale ?? .22,
      seed: 42,
      mode: _mode,
      tuning: _selectedArena?.arenaTrapsEnabled == false
          ? settings.powerUps.withValue('arenaTrapsEnabled', 0)
          : settings.powerUps,
      skillLibrary: skillLibrary,
      lookAhead: false,
      slowMotionLines: 0,
      endlessBattle: _endless,
      dualWield: true,
      arenaDecoration:
          _selectedArena?.trapTheme ?? _arenaChoice ?? settings.arenaDecoration,
    );
    _match!.powerUps!.automaticSpawning = _randomSpawns;
    final balls = _match!.state.balls;
    final distance = math.max(
      _layout == 'Contact' ? balls.first.radius : 75.0,
      _selectedArena?.obstacle == null ||
              _selectedArena!.obstacle == CenterObstacle.none
          ? 0.0
          : 200 * _selectedArena!.obstacleScale + balls.first.radius + 4,
    );
    if (_layout != 'Natural') {
      balls[0].position = Offset(-distance, 0);
      balls[1].position = Offset(distance, 0);
      balls[0].velocity = const Offset(100, 0);
      balls[1].velocity = const Offset(-100, 0);
    }
    for (var i = 0; i < balls.length; i++) {
      _match!.setTestBallPinned(balls[i], _motion[i] == _TestMotion.idle);
      if (_motion[i] == _TestMotion.randomStart) {
        _setRandomStartingDirection(i);
      }
    }
    for (var i = 0; i < _savedItems.length; i++) {
      _reapplyLoadout(i);
    }
    _rearmAllTraps();
    _audio.resetEffects();
    _paused = true;
    _previous = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _previous = null;
  }

  void _tick(Duration elapsed) {
    final previous = _previous;
    _previous = elapsed;
    if (!_foreground ||
        _paused ||
        _dragBall != null ||
        previous == null ||
        _match == null) {
      return;
    }
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    // Ignore background/resume gaps instead of skipping ahead in the fight.
    if (dt <= 0 || dt > 0.25) return;
    setState(() {
      _match!.tick(dt * _speed);
    });
    _playTestSounds();
    if (_match!.state.status == MatchStatus.finished) {
      _ticker.stop();
      _audio.stopMusic();
    }
  }

  final Map<String, int> _heardInteractions = {};
  int _heardCuts = 0;
  int _heardKnockouts = 0;

  void _playTestSounds() {
    final soundController = _match!;
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

    final controller = _match!;
    if (controller.wallHits > _heardWallHits) _audio.bounce();
    if (controller.ballHits > _heardBallHits) _audio.collide();
    _heardWallHits = controller.wallHits;
    _heardBallHits = controller.ballHits;
    final p = controller.powerUps;
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

  void _applyItem(int index, PowerUpKind kind, {String? skillId}) {
    final match = _match!;
    final ball = match.state.balls[index];
    final skill = _selection(kind, skillId)!;
    if (skill.resolvedCategory == SkillCategory.trap ||
        skill.resolvedCategory == SkillCategory.arenaTrap) {
      match.powerUps!.spawnTestItem(kind, skillId: skill.id);
    } else {
      match.powerUps!.pickUp(
        ball,
        FieldPowerUp(
          kind: kind,
          position: ball.position,
          spawnStep: match.stepCount,
          skillId: skill.id,
        ),
      );
    }
  }

  void _reapplyLoadout(int index) {
    final ball = _match!.state.balls[index];
    _match!.powerUps!.resetForRespawn(ball);
    final kinds = [
      _savedItems[index],
      _secondaryWeapons[index],
      _powerUps[index],
    ];
    for (var slot = 0; slot < kinds.length; slot++) {
      final kind = kinds[slot];
      if (kind != null) {
        _replaceLoadoutItem(index, slot, kind, skillId: _skillIds[index][slot]);
      }
    }
  }

  void _replaceLoadoutItem(
    int index,
    int slot,
    PowerUpKind kind, {
    String? skillId,
  }) {
    final ball = _match!.state.balls[index];
    if (slot == 0) {
      ball.held = null;
      ball.heldSkillId = null;
      ball.heldTwoHanded = false;
    } else if (slot == 1) {
      ball.heldSecondary = null;
      ball.heldSecondarySkillId = null;
      ball.heldSecondaryTwoHanded = false;
    }
    final primaryEmpty = ball.held == null;
    _applyItem(index, kind, skillId: skillId);
    if (slot == 1 && primaryEmpty && ball.held != null && !ball.heldTwoHanded) {
      ball.heldSecondary = ball.held;
      ball.heldSecondarySkillId = ball.heldSkillId;
      ball.heldSecondaryTwoHanded = false;
      ball.held = null;
      ball.heldSkillId = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    if (_allowed == true) {
      _audio.stopMusic();
      _audio.startMenuMusic();
    }
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      if (_match!.state.status == MatchStatus.finished) _reset();
      _paused = !_paused;
      _previous = null;
      if (_paused) {
        _ticker.stop();
      } else {
        _ticker.start();
        _audio.startMusic();
      }
    });
  }

  void _setMotion(int index, _TestMotion value) {
    setState(() {
      _motion[index] = value;
      final ball = _match!.state.balls[index];
      _match!.setTestBallPinned(ball, value == _TestMotion.idle);
      if (value == _TestMotion.randomStart) {
        _setRandomStartingDirection(index);
      }
    });
  }

  void _setRandomStartingDirection(int index) {
    final angle = _randomStart.nextDouble() * math.pi * 2;
    _match!.state.balls[index].velocity = Offset.fromDirection(angle, 110);
  }

  Future<void> _chooseLoadoutItem(
    int index,
    int category, {
    bool secondary = false,
  }) async {
    setState(() {
      _paused = true;
      _ticker.stop();
      _previous = null;
    });
    final current = category == 0
        ? (secondary ? _secondaryWeapons[index] : _savedItems[index])
        : _powerUps[index];
    final slot = category == 0 ? (secondary ? 1 : 0) : 2;
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemPicker(
        library: _match!.skillLibrary,
        tuning: _match!.tuning,
        initialTab: category,
        selected: current,
        selectedId: _skillIds[index][slot],
        lockedTab: category,
        onTabChanged: (_) {},
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      final skill = selected is SkillDefinition ? selected : null;
      final kind = skill?.baseKind;
      _skillIds[index][slot] = skill?.id;
      if (category == 0 && secondary) {
        _secondaryWeapons[index] = kind;
        DevicePrefs.write('power-test-secondary-$index', kind?.name ?? 'none');
      } else if (category == 0) {
        _savedItems[index] = kind;
        if (kind != null) _items[index] = kind;
        DevicePrefs.write('power-test-item-$index', kind?.name ?? 'none');
      } else {
        _powerUps[index] = kind;
        DevicePrefs.write('power-test-power-$index', kind?.name ?? 'none');
      }
      if (kind == null) {
        _reapplyLoadout(index);
      } else {
        _replaceLoadoutItem(index, slot, kind, skillId: skill!.id);
      }
      final key = category == 0 ? (secondary ? 'secondary' : 'item') : 'power';
      DevicePrefs.write('power-test-$key-$index-skill-id', skill?.id ?? 'none');
    });
  }

  Future<void> _chooseTrap(int slot) async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemPicker(
        library: _match!.skillLibrary,
        tuning: _match!.tuning,
        initialTab: 2,
        selected: _arenaTraps[slot],
        selectedId: _trapSkillIds[slot],
        lockedTab: 2,
        onTabChanged: (_) {},
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      final skill = selected is SkillDefinition ? selected : null;
      _arenaTraps[slot] = skill?.baseKind;
      _trapSkillIds[slot] = skill?.id;
      DevicePrefs.write('power-test-trap-$slot-skill-id', skill?.id ?? 'none');
      DevicePrefs.write(
        'power-test-trap-$slot',
        _arenaTraps[slot]?.name ?? 'none',
      );
      if (skill == null) {
        _reset();
      } else {
        _rearmTrap(slot);
      }
    });
  }

  void _rearmTrap(int slot) {
    final trap = _arenaTraps[slot];
    if (trap != null) _applyItem(0, trap, skillId: _trapSkillIds[slot]);
  }

  void _rearmAllTraps() {
    for (var i = 0; i < _arenaTraps.length; i++) {
      _rearmTrap(i);
    }
  }

  Future<void> _previewFinisher(
    int index, [
    PowerUpKind? selected,
    String? skillId,
  ]) async {
    final kind = selected ?? _savedItems[index];
    if (kind == null) return;
    final skill = _selection(kind, skillId ?? _skillIds[index][0])!;
    setState(() {
      _paused = true;
      _ticker.stop();
      _previous = null;
    });
    final profile = FinisherProfile.forMove(kind.label);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (previewContext) => ScreenAwake(
          enabled: true,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: HarpoonCinematic(
                      winner: _balls[index],
                      loser: _balls[1 - index],
                      move: skill.name,
                      skill: skill,
                      skillLibrary: _match!.skillLibrary,
                      effectSprites: skill.usesSpriteEffects(
                        globalSprite:
                            AppSettingsScope.of(context).explosionRenderMode ==
                            EffectRenderMode.sprite,
                      ),
                      artworkTint: skill.spriteTint,
                      onHookFired: () => _launchSound(profile),
                      onImpact: () => _impactSound(profile),
                      onFinished: () {
                        GameAudio.instance.win();
                        Navigator.of(previewContext).maybePop();
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(previewContext).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xB3000000),
                        side: const BorderSide(color: Colors.white70),
                      ),
                      icon: const CanvasActionGlyph(
                        CanvasActionGlyphType.close,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Keep the test paused on return so the next action is deliberate.
  }

  static const double _overlaySize = 36;

  Widget _itemPreview(int index) {
    final items = <PowerUpKind?>[
      _savedItems[index],
      _secondaryWeapons[index],
      _powerUps[index],
    ];
    final slots = ['Weapon 1', 'Weapon 2', 'Power-up'];
    return Row(
      key: ValueKey('item-preview-$index'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var slot = 0; slot < items.length; slot++)
          _finisherPreviewSlot(index, slot, slots[slot], items[slot]),
      ],
    );
  }

  Widget _finisherPreviewSlot(
    int ballIndex,
    int slot,
    String slotLabel,
    PowerUpKind? item,
  ) {
    const cellSize = _overlaySize;
    final skill = _selection(item, _skillIds[ballIndex][slot]);
    final enabled = skill?.canDamage ?? false;
    final ball = ballIndex == 0 ? 'A' : 'B';
    final label = item == null
        ? 'Ball $ball $slotLabel: empty'
        : enabled
        ? 'Preview ${skill!.name} finisher for Ball $ball'
        : '${skill?.name ?? item.label} has no finisher';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: enabled,
        child: InkWell(
          key: ValueKey('finisher-preview-$ballIndex-$slot'),
          onTap: enabled
              ? () => _previewFinisher(ballIndex, item, skill!.id)
              : null,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: cellSize,
            height: cellSize,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              border: Border.all(
                color: enabled
                    ? _balls[ballIndex].primaryColor.withValues(alpha: 0.75)
                    : Colors.white24,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: item == null
                ? const Icon(Icons.remove, size: 16, color: Colors.white24)
                : Opacity(
                    opacity: enabled ? 1 : 0.35,
                    child: PowerUpIcon(
                      item,
                      useSettingsArtwork: false,
                      spriteId: skill?.iconSpriteId,
                      size: 27,
                      tint: skill?.spriteTint ?? 0xFFFFFFFF,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  void _launchSound(FinisherProfile profile) {
    final audio = GameAudio.instance;
    switch (profile.style) {
      case FinisherStyle.projectile:
        audio.shot();
      case FinisherStyle.barrage:
        profile.move == 'Gatling' ? audio.gatling() : audio.shotgun();
      case FinisherStyle.melee:
        audio.slash();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        audio.bomb();
      case FinisherStyle.hook:
        audio.shotgun();
      case FinisherStyle.aura:
        audio.shield();
      case FinisherStyle.warp:
        audio.pickup();
    }
  }

  void _impactSound(FinisherProfile profile) {
    final audio = GameAudio.instance;
    switch (profile.style) {
      case FinisherStyle.projectile:
      case FinisherStyle.barrage:
      case FinisherStyle.hook:
        audio.hit();
      case FinisherStyle.melee:
        audio.collide();
      case FinisherStyle.blast:
      case FinisherStyle.trap:
        audio.bomb();
      case FinisherStyle.aura:
        audio.shield();
      case FinisherStyle.warp:
        audio.pickup();
    }
  }

  static final _overlayShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
  );
  Widget _motionButtons(int index) {
    final label = index == 0 ? 'A' : 'B';
    final color = _balls[index].primaryColor;
    return Column(
      key: ValueKey('motion-$label'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in [
          (_TestMotion.moving, Icons.directions_run, 'Moving'),
          (_TestMotion.idle, Icons.pause, 'Idle'),
          (_TestMotion.randomStart, Icons.shuffle, 'Random'),
        ])
          SizedBox.square(
            dimension: _overlaySize,
            child: Semantics(
              selected: _motion[index] == option.$1,
              child: IconButton(
                key: ValueKey('motion-$label-${option.$1.name}'),
                tooltip: 'Ball $label: ${option.$3}',
                style: IconButton.styleFrom(
                  shape: _overlayShape,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: _motion[index] == option.$1
                      ? color
                      : const Color(0xD9000000),
                  side: BorderSide(color: color.withValues(alpha: .5)),
                  foregroundColor:
                      _motion[index] == option.$1 &&
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.light
                      ? Colors.black
                      : Colors.white,
                ),
                icon: Icon(option.$2, size: 22),
                onPressed: () => _setMotion(index, option.$1),
              ),
            ),
          ),
      ],
    );
  }

  Widget _arena({double? squareSide}) {
    final match = _match!;
    final state = match.state;
    final finished = state.status == MatchStatus.finished;
    final stack = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  Offset world(Offset p) =>
                      (p - Offset(bounds.maxWidth / 2, bounds.maxHeight / 2)) *
                      (2 * match.arenaRadius / bounds.maxWidth);
                  return GestureDetector(
                    key: const Key('test-arena-drag'),
                    onPanStart: (details) {
                      final point = world(details.localPosition);
                      final balls =
                          state.balls
                              .where(
                                (b) =>
                                    !b.isEliminated &&
                                    (b.position - point).distance <=
                                        b.radius * 1.5,
                              )
                              .toList()
                            ..sort(
                              (a, b) => (a.position - point).distance.compareTo(
                                (b.position - point).distance,
                              ),
                            );
                      setState(() => _dragBall = balls.firstOrNull);
                    },
                    onPanUpdate: (details) {
                      if (_dragBall case final ball?) {
                        setState(
                          () => match.placeTestBall(
                            ball,
                            world(details.localPosition),
                          ),
                        );
                      }
                    },
                    onPanEnd: (_) => setState(() {
                      _dragBall = null;
                      _previous = null;
                    }),
                    onPanCancel: () => setState(() {
                      _dragBall = null;
                      _previous = null;
                    }),
                    child: RepaintBoundary(
                      child: ArenaCanvas(
                        state: state,
                        arenaRadius: match.arenaRadius,
                        rimInset: 0,
                        rimAngle: 0,
                        look: BallLook.faces,
                        showHpBars: true,
                        arenaTitle: AppSettingsScope.of(context).arenaTitle,
                        arenaSubtitle: AppSettingsScope.of(
                          context,
                        ).arenaSubtitle,
                        arenaPreset: _selectedArena,
                        arenaDecoration:
                            _selectedArena?.trapTheme ??
                            _arenaChoice ??
                            AppSettingsScope.of(context).arenaDecoration,
                        projectileRenderMode: AppSettingsScope.of(
                          context,
                        ).projectileRenderMode,
                        explosionRenderMode: AppSettingsScope.of(
                          context,
                        ).explosionRenderMode,
                        freezeRenderMode: AppSettingsScope.of(
                          context,
                        ).freezeRenderMode,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(left: 4, top: 4, bottom: 48, width: 36, child: _ballRail(0)),
        Positioned(
          right: 4,
          top: 4,
          bottom: 48,
          width: 36,
          child: _ballRail(1),
        ),
        Positioned(left: 0, right: 0, bottom: 4, child: _trapRail()),
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (squareSide != null)
          SizedBox.square(dimension: squareSide, child: stack)
        else
          Expanded(child: stack),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            finished
                ? 'Winner: ${state.balls.firstWhere((b) => b.config.id == state.winnerId).config.name}'
                : '${_paused ? "Paused" : "Running"} - ${(state.step / 60).toStringAsFixed(1)} s',
          ),
        ),
        Text(
          state.balls
              .map(
                (ball) =>
                    '${ball.config.name}: ${_mode == MatchMode.arsenal ? "${ball.life.toStringAsFixed(0)} life" : "${ball.fanLines.length} threads"}'
                    '${ball.isEliminated ? " (out)" : ""}',
              )
              .join(' / '),
        ),
      ],
    );
  }

  Widget _ballRail(int index) => SingleChildScrollView(
    key: ValueKey('ball-rail-$index'),
    child: Column(
      children: [
        SizedBox.square(
          dimension: _overlaySize,
          child: IconButton(
            key: ValueKey('toggle-test-rail-$index'),
            tooltip:
                '${_collapsedRails[index] ? 'Show' : 'Hide'} Ball ${index == 0 ? 'A' : 'B'} controls',
            style: IconButton.styleFrom(
              shape: _overlayShape,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: const Color(0xD9000000),
              foregroundColor: _balls[index].primaryColor,
              side: BorderSide(
                color: _balls[index].primaryColor.withValues(alpha: .5),
              ),
            ),
            icon: Icon(
              (index == 0) == !_collapsedRails[index]
                  ? Icons.chevron_left
                  : Icons.chevron_right,
            ),
            onPressed: () {
              setState(() => _collapsedRails[index] = !_collapsedRails[index]);
              DevicePrefs.write(
                'power-test-rail-$index-collapsed',
                _collapsedRails[index] ? '1' : '0',
              );
            },
          ),
        ),
        if (!_collapsedRails[index]) ...[
          _motionButtons(index),
          const SizedBox(height: 4),
          for (var slot = 0; slot < 3; slot++)
            _loadoutSlot(
              buttonKey: ValueKey(
                slot == 0
                    ? 'choose-item-$index'
                    : slot == 1
                    ? 'choose-weapon-2-$index'
                    : 'choose-power-$index',
              ),
              label: const ['Weapon 1', 'Weapon 2', 'Power-up'][slot],
              item: slot == 0
                  ? _savedItems[index]
                  : slot == 1
                  ? _secondaryWeapons[index]
                  : _powerUps[index],
              skillId: _skillIds[index][slot],
              onChoose: () => _chooseLoadoutItem(
                index,
                slot == 2 ? 1 : 0,
                secondary: slot == 1,
              ),
              onRearm: () => _rearmItem(
                index,
                slot == 0
                    ? _savedItems[index]
                    : slot == 1
                    ? _secondaryWeapons[index]
                    : _powerUps[index],
                slot: slot,
              ),
            ),
        ],
      ],
    ),
  );

  Widget _trapRail() => Center(
    child: Material(
      color: const Color(0xD9000000),
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _arenaTraps.length; i++)
            _loadoutSlot(
              buttonKey: ValueKey('choose-arena-trap-$i'),
              label: 'Trap ${i + 1}',
              item: _arenaTraps[i],
              skillId: _trapSkillIds[i],
              onChoose: () => _chooseTrap(i),
              onRearm: () => setState(() => _rearmTrap(i)),
            ),
        ],
      ),
    ),
  );

  void _rearmItem(int index, PowerUpKind? item, {int slot = 0}) {
    if (item == null) return;
    setState(
      () => _replaceLoadoutItem(
        index,
        slot,
        item,
        skillId: _skillIds[index][slot],
      ),
    );
  }

  Widget _loadoutSlot({
    required Key buttonKey,
    required String label,
    required PowerUpKind? item,
    String? skillId,
    required VoidCallback onChoose,
    required VoidCallback onRearm,
  }) => SizedBox.square(
    dimension: _overlaySize,
    child: _loadoutButton(
      key: buttonKey,
      compact: true,
      label: label,
      item: item,
      skillId: skillId,
      onTap: item == null ? onChoose : onRearm,
      onLongPress: onChoose,
    ),
  );

  Widget _loadoutButton({
    Key? key,
    bool compact = false,
    required String label,
    required PowerUpKind? item,
    String? skillId,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) => Tooltip(
    message: item == null
        ? 'Choose $label'
        : '${_selection(item, skillId)?.name ?? item.label}: tap to re-arm, hold to replace',
    child: Semantics(
      label: item == null
          ? 'Choose $label'
          : '$label: ${_selection(item, skillId)?.name ?? item.label}. Tap to re-arm. Hold to replace.',
      button: true,
      onLongPress: onLongPress,
      child: GestureDetector(
        key: key,
        onLongPress: onLongPress,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            shape: _overlayShape,
            backgroundColor: compact ? const Color(0xD9000000) : null,
            foregroundColor: compact ? Colors.white : null,
            minimumSize: compact
                ? const Size(_overlaySize, _overlaySize)
                : null,
            maximumSize: compact
                ? const Size(_overlaySize, _overlaySize)
                : null,
            tapTargetSize: compact ? MaterialTapTargetSize.shrinkWrap : null,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 2 : 7,
              vertical: compact ? 2 : 8,
            ),
          ),
          child: item != null
              ? PowerUpIcon(
                  item,
                  useSettingsArtwork: false,
                  spriteId: _selection(item, skillId)?.iconSpriteId,
                  size: compact ? 27 : 30,
                  tint: _selection(item, skillId)?.spriteTint ?? 0xFFFFFFFF,
                )
              : compact
              ? const Icon(Icons.add_circle_outline, size: 22)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 20),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );

  Future<void> _showSetup() async {
    setState(() {
      _paused = true;
      _ticker.stop();
      _previous = null;
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          void change(VoidCallback update) {
            setState(() {
              update();
              _reset();
            });
            refresh(() {});
          }

          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Fight setup'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close setup',
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
                const Text(
                  'Changes reset and pause the fight. Selected items are restored.',
                ),
                DropdownButtonFormField<MatchMode>(
                  initialValue: _mode,
                  decoration: const InputDecoration(labelText: 'Fight mode'),
                  items: const [
                    DropdownMenuItem(
                      value: MatchMode.arsenal,
                      child: Text('Arsenal'),
                    ),
                    DropdownMenuItem(
                      value: MatchMode.allOut,
                      child: Text('All-Out'),
                    ),
                  ],
                  onChanged: (value) => change(() => _mode = value!),
                ),
                DropdownButtonFormField<ArenaShape>(
                  key: ValueKey('power-test-arena-shape-${_arenaShape.name}'),
                  initialValue: _arenaShape,
                  decoration: const InputDecoration(labelText: 'Arena shape'),
                  items: const [
                    DropdownMenuItem(
                      value: ArenaShape.circle,
                      child: Text('Circle'),
                    ),
                    DropdownMenuItem(
                      value: ArenaShape.square,
                      child: Text('Square'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    DevicePrefs.write('power-test-arena-shape', value.name);
                    change(() => _arenaShape = value);
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: _layout,
                  decoration: const InputDecoration(
                    labelText: 'Starting positions',
                  ),
                  items: [
                    for (final layout in ['Separated', 'Contact', 'Natural'])
                      DropdownMenuItem(value: layout, child: Text(layout)),
                  ],
                  onChanged: (value) => change(() => _layout = value!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Random item spawns'),
                  value: _randomSpawns,
                  onChanged: (value) => change(() => _randomSpawns = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Endless fight'),
                  value: _endless,
                  onChanged: (value) => change(() => _endless = value),
                ),
                const Text(
                  'Freeze holds a ball in place while attacks and timers continue. '
                  'Unlock to test hooks, portals or knockback. Traps appear near the rim. '
                  'Tap an item to re-arm it; hold to replace it or choose No item.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changeArena() async {
    final active =
        _selectedArena?.trapTheme ??
        _arenaChoice ??
        AppSettingsScope.of(context).arenaDecoration;
    ArenaDefinition? custom;
    final picked = await showArenaSelectionDialog(
      context,
      selected: active,
      selectedPresetId:
          _arenaPresetId ?? AppSettingsScope.of(context).arenaCatalog.defaultId,
      shape: _arenaShape,
      onSelectPreset: (arena) => custom = arena,
      transientPresets: [?widget.initialArena],
    );
    if (picked == null || !mounted) return;
    final isDraft = custom != null && custom!.id == widget.initialArena?.id;
    if (!isDraft) {
      DevicePrefs.write('power-test-arena', picked.name);
      DevicePrefs.write('power-test-arena-preset', custom?.id ?? '');
      if (custom != null) {
        DevicePrefs.write('power-test-arena-shape', custom!.shape.name);
      }
    }
    setState(() {
      _arenaChoice = picked;
      _arenaDraft = isDraft ? widget.initialArena : null;
      _arenaPresetId = custom?.id ?? '';
      if (custom != null) _arenaShape = custom!.shape;
      _reset();
    });
  }

  Widget _playback() {
    final match = _match!;
    final finished = match.state.status == MatchStatus.finished;
    const speeds = [.5, 1.0, 2.0];
    final nextSpeed = speeds[(speeds.indexOf(_speed) + 1) % speeds.length];
    final arenaLabel =
        _selectedArena?.name ??
        (_arenaChoice ?? AppSettingsScope.of(context).arenaDecoration).label;
    final playbackLabel = finished
        ? 'Replay'
        : _paused
        ? 'Play'
        : 'Pause';
    Widget cell(Widget child) =>
        SizedBox.square(dimension: _overlaySize, child: child);
    Widget tools(List<Widget> children) => Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: children,
      ),
    );
    final iconStyle = IconButton.styleFrom(
      shape: _overlayShape,
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(_overlaySize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'A',
                  style: TextStyle(
                    color: _balls[0].primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                _itemPreview(0),
                const Spacer(),
                _itemPreview(1),
                const SizedBox(width: 4),
                Text(
                  'B',
                  style: TextStyle(
                    color: _balls[1].primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              tools([
                cell(
                  IconButton.outlined(
                    key: const ValueKey('test-reset'),
                    tooltip: 'Reset Fight',
                    style: iconStyle,
                    onPressed: () => setState(_reset),
                    icon: const Icon(Icons.restart_alt, size: 22),
                  ),
                ),
                cell(
                  IconButton.outlined(
                    key: const ValueKey('test-skip-frame'),
                    tooltip: 'Skip Frame',
                    style: iconStyle,
                    onPressed: !_paused || finished
                        ? null
                        : () => setState(() {
                            match.tick(
                              MatchSimulationController.fixedTimestep /
                                  match.playbackSpeedUp,
                            );
                            _playTestSounds();
                          }),
                    icon: const Icon(Icons.skip_next, size: 22),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              SizedBox.square(
                dimension: 72,
                child: IconButton.filled(
                  key: const ValueKey('test-playback'),
                  tooltip: playbackLabel,
                  style: IconButton.styleFrom(
                    shape: _overlayShape,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(72),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _togglePlayback,
                  icon: Icon(
                    finished || _paused ? Icons.play_arrow : Icons.pause,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              tools([
                cell(
                  Tooltip(
                    message:
                        'Playback speed: ${_speed}x. Tap for ${nextSpeed}x',
                    child: OutlinedButton(
                      key: const ValueKey('test-speed'),
                      style: OutlinedButton.styleFrom(
                        shape: _overlayShape,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(_overlaySize),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _speed = nextSpeed),
                      child: Text(
                        '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                      ),
                    ),
                  ),
                ),
                cell(
                  IconButton.outlined(
                    key: const ValueKey('test-arena'),
                    tooltip: 'Change arena: $arenaLabel',
                    style: iconStyle,
                    onPressed: _changeArena,
                    icon: const Icon(Icons.stadium_outlined, size: 20),
                  ),
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GameWorkbench(builder: _buildWorkbench);

  Widget _buildWorkbench(BuildContext context) {
    if (_allowed != true || _match == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Power-up Tests')),
        body: Center(
          child: _allowed == null
              ? const CircularProgressIndicator()
              : const Text('Admin access required.'),
        ),
      );
    }
    return ScreenAwake(
      enabled: !_paused && _match!.state.status != MatchStatus.finished,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Power-up Test',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            const AudioChannelButton(
              key: ValueKey('audio-BGM'),
              channel: AudioChannel.bgm,
            ),
            const AudioChannelButton(
              key: ValueKey('audio-SFX'),
              channel: AudioChannel.sfx,
            ),
            const AudioChannelButton(
              key: ValueKey('audio-UX'),
              channel: AudioChannel.ux,
            ),
            IconButton(
              tooltip: 'Fight setup',
              onPressed: _showSetup,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, bounds) => SingleChildScrollView(
              key: const ValueKey('test-stage-scroll'),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: bounds.maxHeight),
                child: Center(
                  child: Column(
                    key: const ValueKey('test-stage'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _arena(squareSide: bounds.maxWidth),
                      const SizedBox(height: 8),
                      _playback(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({
    required this.tuning,
    required this.library,
    required this.initialTab,
    required this.selected,
    required this.onTabChanged,
    this.lockedTab,
    this.selectedId,
  });
  final PowerUpConfig tuning;
  final SkillLibrary library;
  final String? selectedId;
  final int initialTab;
  final PowerUpKind? selected;
  final ValueChanged<int> onTabChanged;
  final int? lockedTab;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  String _query = '';
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final searching = query.isNotEmpty && widget.lockedTab == null;
    final activeTab = widget.lockedTab ?? _tab;
    final items =
        widget.library
            .all(widget.tuning)
            .where(
              (skill) =>
                  (searching ||
                      (activeTab == 0
                          ? skill.resolvedCategory == SkillCategory.weapon
                          : activeTab == 1
                          ? skill.resolvedCategory == SkillCategory.powerUp
                          : skill.resolvedCategory == SkillCategory.trap ||
                                skill.resolvedCategory ==
                                    SkillCategory.arenaTrap)) &&
                  skill.name.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            final selectedId =
                widget.selectedId ??
                (widget.selected == null
                    ? null
                    : 'builtin.${widget.selected!.name}');
            if (a.id == selectedId) return -1;
            if (b.id == selectedId) return 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: DefaultTabController(
          length: 3,
          initialIndex: widget.initialTab,
          child: Column(
            children: [
              ListTile(
                title: const Text('Choose an item'),
                trailing: IconButton(
                  tooltip: 'Close item picker',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search all items',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              if (widget.lockedTab == null)
                TabBar(
                  onTap: (index) {
                    setState(() => _tab = index);
                    widget.onTabChanged(index);
                  },
                  tabs: const [
                    Tab(text: 'Weapons'),
                    Tab(text: 'Power-ups'),
                    Tab(text: 'Traps'),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    const ['Weapons', 'Power-ups', 'Arena traps'][activeTab],
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              if (searching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Results from all categories'),
                ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('No item'),
                onTap: () => Navigator.pop(context, 'none'),
              ),
              Expanded(
                child: items.isEmpty
                    ? const AnimatedEmptyState(
                        message: 'No matching items',
                        icon: Icons.search_off,
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected =
                              item.id ==
                              (widget.selectedId ??
                                  'builtin.${widget.selected?.name}');
                          final rarity = SkillLibrary.rarityOf(
                            item,
                            widget.tuning,
                          );
                          return ListTile(
                            key: ValueKey(
                              item.custom
                                  ? 'power-test-skill-${item.id}'
                                  : 'power-test-item-${item.baseKind.name}',
                            ),
                            minVerticalPadding: 12,
                            selected: selected,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            leading: PowerUpIcon(
                              item.displayKind,
                              size: 32,
                              spriteId: item.iconSpriteId,
                              tint: item.spriteTint,
                              useSettingsArtwork: false,
                            ),
                            title: Text(
                              item.name,
                              style: TextStyle(color: rarity?.color),
                            ),
                            subtitle: Text(
                              '${item.custom ? "Custom · " : ""}${item.resolvedCategory == SkillCategory.arenaTrap
                                  ? "Arena trap"
                                  : item.resolvedCategory == SkillCategory.trap
                                  ? "Trap"
                                  : "${rarity?.label ?? ""} ${item.resolvedCategory == SkillCategory.weapon ? "weapon" : "power-up"}"}${item.enabled ? "" : " · Disabled in matches"}',
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.add_circle_outline),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
