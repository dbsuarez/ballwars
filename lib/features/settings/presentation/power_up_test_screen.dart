import '../../../core/audio/game_audio.dart';
import '../../../core/offline/device_prefs.dart';
import '../../arena_simulation/presentation/finisher_profile.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../../core/widgets/screen_awake.dart';
import '../../../core/widgets/animated_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/simulation_state.dart';
import '../../arena_simulation/presentation/arena_canvas.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/power_up_name.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../../skills/domain/skill_library.dart';
import 'app_settings_scope.dart';

/// Runs actual matches with local, admin-only scenario controls.
class PowerUpTestScreen extends StatefulWidget {
  const PowerUpTestScreen({super.key, this.initialSkill});

  /// An unsaved editor draft to inject into this test session only.
  final SkillDefinition? initialSkill;

  @override
  State<PowerUpTestScreen> createState() => _PowerUpTestScreenState();
}

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
  String _layout = 'Separated';
  final _pinned = [false, false];
  final _items = [PowerUpKind.pistol, PowerUpKind.shield];
  final List<PowerUpKind?> _savedItems = [PowerUpKind.pistol, null];
  final List<PowerUpKind?> _secondaryWeapons = [null, PowerUpKind.shield];
  final List<PowerUpKind?> _powerUps = [null, null];
  PowerUpKind? _arenaTrap;
  final _pickerTabs = [0, 0];

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
      _items[0] = initialSkill.baseKind;
      _savedItems[0] = initialSkill.baseKind;
      _pickerTabs[0] = initialSkill.baseKind.isWeapon
          ? 0
          : initialSkill.baseKind.isTrap
          ? 2
          : 1;
    }
    if (!mounted) return;
    setState(() {
      _allowed = allowed;
      if (allowed) {
        _audio.stopMenuMusic();
        _reset();
      }
    });
  }

  Future<void> _loadRememberedChoices() async {
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
    }
    _arenaTrap = _rememberedKind(await DevicePrefs.read('power-test-trap'));
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
        ? settings.skillLibrary
        : settings.skillLibrary.withDefinition(
            initialSkill.copyWith(enabled: true),
            settings.powerUps,
          );
    _match = MatchSimulationController(
      _balls,
      arenaRadius: 200,
      seed: 42,
      mode: _mode,
      tuning: settings.powerUps,
      skillLibrary: skillLibrary,
      lookAhead: false,
      slowMotionLines: 0,
      endlessBattle: _endless,
      dualWield: true,
      arenaDecoration: settings.arenaDecoration,
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
    for (var i = 0; i < _savedItems.length; i++) {
      _reapplyLoadout(i);
    }
    if (_arenaTrap != null) _applyItem(0, _arenaTrap!);
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
    if (!_foreground || _paused || previous == null || _match == null) return;
    final dt = (elapsed - previous).inMicroseconds / 1000000;
    // Ignore background/resume gaps instead of skipping ahead in the fight.
    if (dt <= 0 || dt > 0.25) return;
    setState(() => _match!.tick(dt * _speed));
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

  void _applyItem(int index, PowerUpKind kind) {
    final match = _match!;
    final ball = match.state.balls[index];
    if (kind.isTrap) {
      match.powerUps!.spawnTestItem(kind);
    } else {
      match.powerUps!.pickUp(
        ball,
        FieldPowerUp(
          kind: kind,
          position: ball.position,
          spawnStep: match.stepCount,
        ),
      );
    }
  }

  void _reapplyLoadout(int index) {
    final ball = _match!.state.balls[index];
    _match!.powerUps!.resetForRespawn(ball);
    for (final kind in [
      _savedItems[index],
      _secondaryWeapons[index],
      _powerUps[index],
    ]) {
      if (kind != null) _applyItem(index, kind);
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

  void _freeze(int index, bool value) {
    setState(() {
      _pinned[index] = value;
      _match!.setTestBallPinned(_match!.state.balls[index], value);
    });
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
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemPicker(
        tuning: _match!.tuning,
        initialTab: category,
        selected: current,
        lockedTab: category,
        onTabChanged: (_) {},
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      final kind = selected is PowerUpKind ? selected : null;
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
      _reapplyLoadout(index);
    });
  }

  Future<void> _chooseTrap() async {
    final selected = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemPicker(
        tuning: _match!.tuning,
        initialTab: 2,
        selected: _arenaTrap,
        lockedTab: 2,
        onTabChanged: (_) {},
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _arenaTrap = selected is PowerUpKind ? selected : null;
      DevicePrefs.write('power-test-trap', _arenaTrap?.name ?? 'none');
      if (_arenaTrap != null) _applyItem(0, _arenaTrap!);
    });
  }

  Future<void> _previewFinisher(int index) async {
    final kind = _savedItems[index];
    if (kind == null) return;
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
                      move: kind.label,
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
                    child: IconButton.filledTonal(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(previewContext).maybePop(),
                      icon: const Text(
                        '×',
                        style: TextStyle(fontSize: 28, height: 1),
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

  Widget _itemPreview(int index) {
    final item = _savedItems[index];
    final label = item == null
        ? 'Ball ${index == 0 ? "A" : "B"}: no item'
        : 'Preview ${item.label} finisher for Ball ${index == 0 ? "A" : "B"}';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        enabled: item != null,
        child: InkWell(
          key: ValueKey('item-preview-$index'),
          onTap: item == null ? null : () => _previewFinisher(index),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: 64,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // A fixed frame and crosshairs make centering and bleed visible.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _balls[index].primaryColor.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Container(width: 1, height: 64, color: Colors.white12),
                Container(width: 64, height: 1, color: Colors.white12),
                if (item != null)
                  PowerUpIcon(item, size: 48)
                else
                  const Icon(Icons.remove, color: Colors.white38),
              ],
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

  Widget _arena() {
    final match = _match!;
    final state = match.state;
    final finished = state.status == MatchStatus.finished;
    return Column(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: RepaintBoundary(
                      child: ArenaCanvas(
                        state: state,
                        arenaRadius: match.arenaRadius,
                        rimInset: 0,
                        rimAngle: 0,
                        look: BallLook.faces,
                        arenaTitle: AppSettingsScope.of(context).arenaTitle,
                        arenaSubtitle: AppSettingsScope.of(
                          context,
                        ).arenaSubtitle,
                        arenaDecoration: AppSettingsScope.of(
                          context,
                        ).arenaDecoration,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(left: 4, bottom: 0, child: _itemPreview(0)),
              Positioned(right: 4, bottom: 0, child: _itemPreview(1)),
            ],
          ),
        ),
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
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _freeze(i, !_pinned[i]),
                    icon: Icon(
                      _pinned[i] ? Icons.lock : Icons.directions_run,
                      color: _balls[i].primaryColor,
                    ),
                    label: Text(
                      '${i == 0 ? "A" : "B"}: ${_pinned[i] ? "Frozen" : "Moving"}',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _controls() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 2; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ball ${i == 0 ? "A" : "B"} loadout'),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: _loadoutButton(
                        key: ValueKey('choose-item-$i'),
                        label: 'Weapon 1',
                        item: _savedItems[i],
                        onTap: () => _chooseLoadoutItem(i, 0),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _loadoutButton(
                        key: ValueKey('choose-weapon-2-$i'),
                        label: 'Weapon 2',
                        item: _secondaryWeapons[i],
                        onTap: () => _chooseLoadoutItem(i, 0, secondary: true),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: _loadoutButton(
                        key: ValueKey('choose-power-$i'),
                        label: 'Power-up',
                        item: _powerUps[i],
                        onTap: () => _chooseLoadoutItem(i, 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: _loadoutButton(
            key: const ValueKey('choose-arena-trap'),
            label: 'Arena trap',
            item: _arenaTrap,
            onTap: _chooseTrap,
          ),
        ),
      ],
    ),
  );

  Widget _loadoutButton({
    Key? key,
    required String label,
    required PowerUpKind? item,
    required VoidCallback onTap,
  }) => OutlinedButton(
    key: key,
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item == null)
          const Icon(Icons.add_circle_outline, size: 20)
        else
          PowerUpIcon(item, size: 22),
        Text(
          item?.label ?? label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ],
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
                  'The refresh button beside an item gives it again during a fight.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _audioToggle(String channel) {
    final music = channel == 'BGM';
    final effects = channel == 'SFX';
    final on = music
        ? _audio.musicOn
        : effects
        ? _audio.effectsOn
        : _audio.uxOn;
    return IconButton(
      key: ValueKey('audio-$channel'),
      constraints: const BoxConstraints.tightFor(width: 38, height: 48),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      tooltip: '$channel: ${on ? "on" : "off"}. Long press for volume.',
      onPressed: () async {
        if (music) {
          // Start during the tap gesture, before waiting on preference storage.
          // An explicit BGM preview also works while the simulation is paused.
          final saved = _audio.setMusicOn(!on);
          if (!on) _audio.startMusic();
          setState(() {});
          await saved;
        } else if (effects) {
          final saved = _audio.setEffectsOn(!on);
          if (!on) _audio.click();
          setState(() {});
          await saved;
        } else {
          final saved = _audio.setUxOn(!on);
          setState(() {});
          await saved;
        }
        if (mounted) setState(() {});
      },
      onLongPress: () => _showVolume(channel),
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            music
                ? (on ? Icons.music_note : Icons.music_off)
                : effects
                ? (on ? Icons.volume_up : Icons.volume_off)
                : (on ? Icons.touch_app : Icons.do_not_touch),
            size: 20,
          ),
          Text(channel, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  Future<void> _showVolume(String channel) async {
    var value = channel == 'BGM'
        ? _audio.musicLevel
        : channel == 'SFX'
        ? _audio.effectsLevel
        : _audio.uxLevel;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text('$channel volume'),
          content: Row(
            children: [
              const Icon(Icons.volume_down),
              Expanded(
                child: Slider(
                  value: value,
                  divisions: 10,
                  label: '${(value * 100).round()}%',
                  onChanged: (next) => refresh(() => value = next),
                ),
              ),
              Text('${(value * 100).round()}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (channel == 'BGM') await _audio.setMusicLevel(value);
                if (channel == 'SFX') await _audio.setEffectsLevel(value);
                if (channel == 'UX') await _audio.setUxLevel(value);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Widget _playback() {
    final match = _match!;
    final finished = match.state.status == MatchStatus.finished;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: _togglePlayback,
                    icon: Icon(
                      finished || _paused ? Icons.play_arrow : Icons.pause,
                    ),
                    label: Text(
                      finished
                          ? 'Replay'
                          : _paused
                          ? 'Play'
                          : 'Pause',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => setState(_reset),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset Fight'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: !_paused || finished
                        ? null
                        : () => setState(() {
                            match.tick(
                              MatchSimulationController.fixedTimestep /
                                  match.playbackSpeedUp,
                            );
                            _playTestSounds();
                          }),
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Skip Frame'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: DropdownButtonFormField<double>(
                    initialValue: _speed,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.speed, size: 18),
                      isDense: true,
                    ),
                    items: [
                      for (final speed in [0.25, 0.5, 1.0, 2.0])
                        DropdownMenuItem(
                          value: speed,
                          child: Text('${speed}x'),
                        ),
                    ],
                    onChanged: (value) => setState(() => _speed = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            _audioToggle('BGM'),
            _audioToggle('SFX'),
            _audioToggle('UX'),
            IconButton(
              tooltip: 'Fight setup',
              onPressed: _showSetup,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        bottomNavigationBar: _playback(),
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, bounds) {
              if (bounds.maxWidth >= 600 &&
                  bounds.maxWidth > bounds.maxHeight) {
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _arena(),
                      ),
                    ),
                    Expanded(child: Center(child: _controls())),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: _arena(),
                    ),
                  ),
                  _controls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ItemPicker extends StatefulWidget {
  const _ItemPicker({
    required this.tuning,
    required this.initialTab,
    required this.selected,
    required this.onTabChanged,
    this.lockedTab,
  });
  final PowerUpConfig tuning;
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
        PowerUpKind.values
            .where(
              (kind) =>
                  (searching ||
                      (activeTab == 0
                          ? kind.isWeapon
                          : activeTab == 1
                          ? kind.isPowerUp
                          : kind.isTrap)) &&
                  kind.label.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            if (a == widget.selected) return -1;
            if (b == widget.selected) return 1;
            return a.label.toLowerCase().compareTo(b.label.toLowerCase());
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
                          final selected = item == widget.selected;
                          return ListTile(
                            key: ValueKey('power-test-item-${item.name}'),
                            minVerticalPadding: 12,
                            selected: selected,
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            leading: PowerUpIcon(item, size: 32),
                            title: PowerUpName(item, tuning: widget.tuning),
                            subtitle: Text(
                              '${widget.tuning.rarityOf(item)?.label ?? "Trap"}${item.isTrap
                                  ? ""
                                  : item.isWeapon
                                  ? " weapon"
                                  : " power-up"}',
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
