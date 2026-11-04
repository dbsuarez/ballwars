import '../../sprites/application/skill_sprite_readiness.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/offline/device_prefs.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/arena_canvas.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../match_setup/domain/match_config.dart';
import '../../settings/domain/app_settings.dart';
import '../application/skill_demo_controller.dart';
import '../domain/skill_library.dart';
import 'skill_artwork_tint.dart';
import 'skill_demo_inspector.dart';
import 'grip_preview_dialog.dart';

/// Manual editor showcase, separate from the full Power-up Test workbench.
class SkillDemoDialog extends StatefulWidget {
  const SkillDemoDialog({
    super.key,
    required this.skill,
    required this.library,
    required this.tuning,
    this.effectMode = EffectRenderMode.sprite,
  });
  final SkillDefinition skill;
  final SkillLibrary library;
  final PowerUpConfig tuning;
  final EffectRenderMode effectMode;
  @override
  State<SkillDemoDialog> createState() => _SkillDemoDialogState();
}

class _SkillDemoDialogState extends State<SkillDemoDialog>
    with SingleTickerProviderStateMixin {
  late final SkillDemoController _demo = SkillDemoController(
    skill: widget.skill,
    library: widget.library,
    tuning: widget.tuning,
  );
  late final Ticker _ticker;
  Duration? _previous;
  bool _sound = true;
  bool _speedChosen = false;
  bool _soundChosen = false, _inspectChosen = false;
  bool _distanceChosen = false, _facingChosen = false;
  late final Future<void> _preferences;
  bool _inspect = false;
  String _focusedArtwork = 'Pickup';
  // Event-focused replays stop at the first matching gameplay event. These
  // are real arena events, not a separate fabricated animation timeline.
  String? _awaitedPreviewEvent;
  int _eventStartShots = 0;
  int _eventStartHits = 0;
  int _eventStartBlasts = 0;
  int _eventStartSlashes = 0;
  int _eventStartBlocks = 0;
  int _eventStartImpacts = 0;
  String? _previewEventMessage;
  bool _preparing = false;
  // Invalidates asynchronous artwork preparation when a preview is reset,
  // switched, or the dialog is closed.
  int _previewGeneration = 0;
  String? _error;
  final _heard = <String, int>{};
  int _hits = 0,
      _shots = 0,
      _slashes = 0,
      _blocks = 0,
      _blasts = 0,
      _pickups = 0;
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _preferences = _restorePreferences();
    PowerUpSprites.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _restorePreferences() async {
    final initialGeneration = _previewGeneration;
    final speed = double.tryParse(
      await DevicePrefs.read('skill-demo-speed') ?? '',
    );
    final sound = await DevicePrefs.read('skill-demo-sound');
    final inspect = await DevicePrefs.read('skill-demo-inspect');
    final distance = await DevicePrefs.read('skill-demo-distance');
    final facing = await DevicePrefs.read('skill-demo-facing');
    if (mounted && initialGeneration == _previewGeneration) {
      setState(() {
        if (!_soundChosen && sound != null) _sound = sound == 'true';
        if (!_inspectChosen && inspect != null) _inspect = inspect == 'true';
        if (!_facingChosen && facing != null) {
          _demo.facingRight = facing == 'true';
        }
        final ratio = double.tryParse(distance ?? '');
        if (!_distanceChosen &&
            ratio != null &&
            ratio.isFinite &&
            ratio >= 0 &&
            ratio <= 1) {
          _demo.distanceRatio = ratio;
        }
        // Restoring preferences must not erase a pickup or an already
        // activated preview while asynchronous device storage is loading.
        if (!_demo.started && !_demo.hasPreviewPickup) _demo.reset();
      });
    }
    if (mounted && initialGeneration == _previewGeneration &&
        !_speedChosen && {.25, .5, 1.0}.contains(speed)) {
      setState(() => _demo.speed = speed!);
    }
  }

  void _audio() {
    final p = _demo.match.powerUps!;
    for (final entry in p.skillSounds.entries) {
      if (_sound && entry.value > (_heard[entry.key] ?? 0)) {
        GameAudio.instance.previewSkillCue(entry.key);
      }
      _heard[entry.key] = entry.value;
    }
    if (_sound && p.hits > _hits) GameAudio.instance.previewSkillCue('hit');
    if (_sound && widget.skill.soundCue == 'default') {
      if (p.shots > _shots) {
        GameAudio.instance.previewSkillCue(switch (widget.skill.baseKind) {
          PowerUpKind.shotgun => 'shotgun',
          PowerUpKind.gatling => 'gatling',
          _ => 'shot',
        });
      }
      if (p.slashes > _slashes) GameAudio.instance.previewSkillCue('slash');
      if (p.blocks > _blocks) GameAudio.instance.previewSkillCue('shield');
      if (p.blasts > _blasts) GameAudio.instance.previewSkillCue('bomb');
      if (p.pickups > _pickups && !widget.skill.baseKind.isWeapon) {
        GameAudio.instance.previewSkillCue('pickup');
      }
    }
    _hits = p.hits;
    _shots = p.shots;
    _slashes = p.slashes;
    _blocks = p.blocks;
    _blasts = p.blasts;
    _pickups = p.pickups;
  }

  // Shared by synchronous activation and frame updates. A single event
  // should stop playback regardless of which side of the first tick it occurs.
  void _checkPreviewEvent() {
    final event = _awaitedPreviewEvent;
    if (event == null) return;
    final powerUps = _demo.match.powerUps!;
    final reached = switch (event) {
      'Casting' => powerUps.castingArtwork.isNotEmpty ||
          powerUps.muzzleArtwork.isNotEmpty,
      'Projectile' => powerUps.shots > _eventStartShots ||
          powerUps.projectiles.isNotEmpty,
      'Impact' => powerUps.hits > _eventStartHits ||
          powerUps.blasts > _eventStartBlasts ||
          powerUps.slashes > _eventStartSlashes ||
          powerUps.blocks > _eventStartBlocks ||
          powerUps.weaponImpacts.length > _eventStartImpacts,
      _ => false,
    };
    if (reached) {
      _awaitedPreviewEvent = null;
      _previewEventMessage =
          '$event event reached. Playback paused for inspection.';
      _demo.playing = false;
      _previous = null;
    } else if (!_demo.playing) {
      _awaitedPreviewEvent = null;
      _previewEventMessage = 'No observable $event event occurred during this replay.';
    }
  }

  void _tick(Duration time) {
    final old = _previous;
    _previous = time;
    if (old == null) return;
    try {
      _demo.step((time - old).inMicroseconds / 1000000);
      _audio();
      _checkPreviewEvent();
      if (!_demo.playing) _ticker.stop();
      if (mounted) setState(() {});
    } catch (error) {
      _ticker.stop();
      _previous = null;
      _awaitedPreviewEvent = null;
      _previewEventMessage = null;
      _demo.stopPlayback();
      if (mounted) {
        setState(() => _error = 'Demo could not continue: $error');
      }
    }
  }

  Future<void> _ensureArtwork() async {
    final missing = await SkillSpriteReadiness.prepare(
      library: _demo.match.skillLibrary,
      tuning: widget.tuning,
      kinds: widget.skill.custom ? const {} : {widget.skill.baseKind},
      customIds: widget.skill.custom ? {widget.skill.id} : const {},
      includeTraps: false,
    );
    if (missing.isNotEmpty) {
      throw StateError(
        '${missing.length} artwork assets are unavailable. Reload Sprites, then retry.',
      );
    }
  }

  Future<void> _start() async {
    final generation = ++_previewGeneration;
    _ticker.stop();
    _demo.stopPlayback();
    _previous = null;
    _awaitedPreviewEvent = null;
    _previewEventMessage = null;
    _heard.clear();
    _hits = _shots = _slashes = _blocks = _blasts = _pickups = 0;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      await _preferences;
      await _ensureArtwork();
      if (!mounted || generation != _previewGeneration) return;
      // Activation resets the isolated match. Capture counters from the
      // fresh match before activating, so a previous replay cannot shift
      // the event baseline.
      _demo.reset();
      final powerUps = _demo.match.powerUps!;
      _eventStartShots = powerUps.shots;
      _eventStartHits = powerUps.hits;
      _eventStartBlasts = powerUps.blasts;
      _eventStartSlashes = powerUps.slashes;
      _eventStartBlocks = powerUps.blocks;
      _eventStartImpacts = powerUps.weaponImpacts.length;
      _awaitedPreviewEvent =
          _focusedArtwork == 'Casting' ||
          _focusedArtwork == 'Projectile' ||
          _focusedArtwork == 'Impact'
              ? _focusedArtwork
              : null;
      _demo.activate();
      _audio();
      _checkPreviewEvent();
      setState(() => _error = null);
      if (_demo.playing) _ticker.start();
    } catch (error) {
      if (mounted && generation == _previewGeneration) {
        // A failed replay must never leave the prior arena playing or a
        // stale event target waiting to pause a later replay.
        _ticker.stop();
        _previous = null;
        _awaitedPreviewEvent = null;
        _previewEventMessage = null;
        _demo.stopPlayback();
        setState(() => _error = 'Demo could not start: $error');
      }
    } finally {
      if (mounted && generation == _previewGeneration) {
        setState(() => _preparing = false);
      }
    }
  }

  // Every arena-control mutation invalidates an in-flight asynchronous
  // artwork load. Otherwise a previously requested replay can activate after
  // the user has changed the arena or placed/cleared a pickup.
  void _mutatePreviewArena(VoidCallback mutation) {
    _awaitedPreviewEvent = null;
    _previewEventMessage = null;
    ++_previewGeneration;
    _preparing = false;
    _ticker.stop();
    _previous = null;
    setState(() {
      _demo.stopPlayback();
      mutation();
      _error = null;
    });
  }

  void _changeDistance(double? value) {
    _distanceChosen = true;
    _demo.distanceRatio = value;
    DevicePrefs.write('skill-demo-distance', value ?? 'auto');
    _reset();
  }

  void _reset() {
    _awaitedPreviewEvent = null;
    _previewEventMessage = null;
    ++_previewGeneration;
    _preparing = false;
    _ticker.stop();
    _previous = null;
    setState(() {
      _demo.reset();
      _error = null;
    });
  }

  // Switching artwork focus must not leave a pickup or an earlier skill
  // replay visible under the newly selected mode. Reset only the isolated
  // demo; the editor draft and persistent preferences are untouched.
  void _selectArtworkFocus(String mode) {
    if (_focusedArtwork == mode) return;
    _awaitedPreviewEvent = null;
    _previewEventMessage = null;
    ++_previewGeneration;
    _preparing = false;
    _ticker.stop();
    _previous = null;
    setState(() {
      _focusedArtwork = mode;
      _demo.reset();
      _error = null;
    });
  }

  // Focus actions use the same isolated arena as the normal skill demo.
  // Pickup is an arena object; Equipped inspects the actual held state.
  // Other modes replay the real skill to the first observable event.
  Future<void> _previewFocusedArtwork() async {
    if (_focusedArtwork == 'Pickup') {
      _awaitedPreviewEvent = null;
      _previewEventMessage = null;
      ++_previewGeneration;
      _preparing = false;
      _ticker.stop();
      _previous = null;
      setState(() {
        _demo.reset();
        _demo.spawnPreviewPickup();
        _error = null;
      });
      return;
    }
    if (_focusedArtwork == 'Equipped') {
      _awaitedPreviewEvent = null;
      _previewEventMessage = null;
      ++_previewGeneration;
      _preparing = false;
      _ticker.stop();
      _previous = null;
      setState(() {
        // reset() equips weapons through the same simulation path used by
        // arena matches, without firing a projectile or advancing time.
        _demo.reset();
        _error = null;
      });
      return;
    }
    await _start();
  }

  void _pause() {
    // A finished replay cannot be resumed: the simulation has already
    // reached its bounded end. Use Replay to start a fresh isolated match.
    if (!_demo.started || (!_demo.playing && _demo.elapsed >= _demo.duration)) {
      return;
    }
    setState(() => _demo.playing = !_demo.playing);
    _previous = null;
    _demo.playing ? _ticker.start() : _ticker.stop();
  }

  @override
  void dispose() {
    ++_previewGeneration;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SizedBox(
          height: math.min(800, size.height * .93),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skill Demo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            skill.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('skill-demo-sound'),
                      tooltip: _sound ? 'Mute demo sound' : 'Enable demo sound',
                      onPressed: () {
                        _soundChosen = true;
                        setState(() => _sound = !_sound);
                        DevicePrefs.write('skill-demo-sound', _sound);
                      },
                      icon: Icon(_sound ? Icons.volume_up : Icons.volume_off),
                    ),
                    IconButton(
                      key: const ValueKey('close-skill-demo'),
                      tooltip: 'Close skill demo',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Keep the actual arena renderer visible while the editor controls
              // scroll. Pickup scale comes from the same live match painter.
              Padding(
                key: const ValueKey('skill-demo-pinned-stage'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      LayoutBuilder(
                        builder: (context, bounds) => Center(
                          child: SizedBox.square(
                            dimension: math.min(
                              bounds.maxWidth,
                              math.min(310, size.height * .34),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ArenaCanvas(
                                  key: const ValueKey('skill-demo-arena'),
                                  state: _demo.match.state,
                                  arenaRadius: 180,
                                  rimAngle: 0,
                                  look: BallLook.faces,
                                  arenaTitle: '',
                                  arenaSubtitle: '',
                                  showHpBars: true,
                                  showBallGlow: false,
                                  explosionRenderMode: widget.effectMode,
                                  projectileRenderMode: widget.effectMode,
                                  freezeRenderMode: widget.effectMode,
                                ),
                                if (_inspect)
                                  IgnorePointer(
                                    child: CustomPaint(
                                      painter: SkillDemoCollisionPainter(
                                        _demo.match,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        'Manual activation · targets start still · current unsaved draft',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        children: [
                          DropdownButton<ArenaShape>(
                            key: const ValueKey('skill-demo-arena-shape'),
                            value: _demo.arenaShape,
                            items: [
                              for (final shape in ArenaShape.values)
                                DropdownMenuItem(
                                  value: shape,
                                  child: Text('Arena: ${shape.label}'),
                                ),
                            ],
                            onChanged: (shape) {
                              if (shape == null) return;
                              _mutatePreviewArena(() {
                                _demo.arenaShape = shape;
                                _demo.reset();
                              });
                            },
                          ),
                          DropdownButton<CenterObstacle>(
                            key: const ValueKey('skill-demo-center-obstacle'),
                            value: _demo.centerObstacle,
                            items: [
                              for (final obstacle in CenterObstacle.values)
                                DropdownMenuItem(
                                  value: obstacle,
                                  child: Text('Obstacle: ${obstacle.label}'),
                                ),
                            ],
                            onChanged: (obstacle) {
                              if (obstacle == null) return;
                              _mutatePreviewArena(() {
                                _demo.centerObstacle = obstacle;
                                _demo.reset();
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Caster ${_demo.match.state.balls.first.life.round()} HP',
                                key: const ValueKey('demo-caster-health'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${_demo.playing
                                    ? "Playing"
                                    : !_demo.started
                                    ? "Ready"
                                    : _demo.elapsed >= _demo.duration
                                    ? "Done"
                                    : "Paused"} · ${_demo.elapsed.toStringAsFixed(1)} s',
                                key: const ValueKey('demo-status'),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Target ${_demo.match.state.balls.last.life.round()} HP',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Text('Ball distance')),
                          Text(
                            _demo.distanceRatio == null
                                ? 'Automatic'
                                : '${(_demo.distanceRatio! * 100).round()}%',
                          ),
                        ],
                      ),
                      Slider(
                        key: const ValueKey('skill-demo-distance'),
                        value: _demo.distanceRatio ?? .5,
                        min: 0,
                        max: 1,
                        divisions: 100,
                        onChanged: _changeDistance,
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final preset in [
                            ('Near', 0.0),
                            ('Mid', .5),
                            ('Far', 1.0),
                          ])
                            OutlinedButton(
                              onPressed: () => _changeDistance(preset.$2),
                              child: Text(preset.$1),
                            ),
                          TextButton(
                            onPressed: () => _changeDistance(null),
                            child: const Text('Auto'),
                          ),
                        ],
                      ),
                      const Text(
                        'Changing distance resets the demo.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Artwork focus', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        key: const ValueKey('skill-demo-artwork-modes'),
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final mode in const [
                            'Casting', 'Equipped', 'Projectile', 'Impact', 'Pickup',
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ChoiceChip(
                                  key: ValueKey('skill-demo-mode-${mode.toLowerCase()}'),
                                  label: Text(mode),
                                  selected: _focusedArtwork == mode,
                                  onSelected: (_) => _selectArtworkFocus(mode),
                                ),
                                IconButton(
                                  key: ValueKey('skill-demo-edit-${mode.toLowerCase()}'),
                                  tooltip: 'Edit $mode settings',
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  onPressed: () => Navigator.pop(context, mode),
                                  icon: const Icon(Icons.tune),
                                ),
                              ],
                            ),
                        ],
                      ),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('skill-demo-spawn-pickup'),
                            onPressed: () => _mutatePreviewArena(_demo.spawnPreviewPickup),
                            icon: const Icon(Icons.add_location_alt_outlined),
                            label: const Text('Spawn pickup'),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('skill-demo-clear-pickup'),
                            onPressed: _demo.hasPreviewPickup
                                ? () => _mutatePreviewArena(_demo.clearPreviewPickup)
                                : null,
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear pickup'),
                          ),
                        ],
                      ),
                      Text(
                        'Pickup displayed at match size (${_demo.match.skillLibrary.pickupDisplayScaleFor(skill).toStringAsFixed(2)}x) near the upper arena. Reset clears it.',
                        key: const ValueKey('skill-demo-pickup-scale'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('skill-demo-preview-focused-artwork'),
                            onPressed: _preparing ? null : _previewFocusedArtwork,
                            icon: const Icon(Icons.play_circle_outline),
                            label: Text(switch (_focusedArtwork) {
                              'Pickup' => 'Show pickup in arena',
                              'Equipped' => 'Inspect equipped in arena',
                               'Casting' => 'Replay to first casting event',
                               'Projectile' => 'Replay to first projectile',
                               'Impact' => 'Replay to first impact',
                               _ => 'Replay skill in arena',
                            }),
                          ),
                          if (skill.resolvedCategory == SkillCategory.weapon)
                            OutlinedButton.icon(
                              key: const ValueKey('skill-demo-attack-timeline'),
                              onPressed: () => GripPreviewDialog.show(
                                context,
                                kind: skill.baseKind,
                                skill: skill,
                                spriteId: skill.effectiveHeldSpriteId,
                                pickupSpriteId: skill.effectivePickupSpriteId,
                                projectileSpriteId: skill.projectileSpriteId,
                                impactSpriteId: skill.impactSpriteId,
                                displayScale: skill.weaponDisplayScale,
                                tint: skill.spriteTint,
                                useSprite: skill.spriteMode == SkillVisualMode.sprite,
                                grip: GripValues(
                                  attackAnimation: skill.heldAttackAnimation,
                                  attackRepeatCount: skill.heldAttackRepeatCount,
                                  attackDurationSteps: skill.heldAttackDurationSteps,
                                  attackArcScale: skill.heldAttackArcScale,
                                  attackVfxScale: skill.heldAttackVfxScale,
                                  inset: skill.weaponGripInset,
                                  side: skill.weaponGripSide,
                                  rotation: skill.weaponGripRotation,
                                  facing: skill.heldFacing,
                                  heldAttachment: skill.heldAttachment,
                                  effectAttachment: skill.effectAttachment,
                                  heldOffsetX: skill.heldOffsetX,
                                  heldOffsetY: skill.heldOffsetY,
                                  effectOffsetX: skill.effectOffsetX,
                                  effectOffsetY: skill.effectOffsetY,
                                ),
                              ),
                              icon: const Icon(Icons.slow_motion_video),
                              label: const Text('Attack timeline'),
                            ),
                          TextButton.icon(
                            key: const ValueKey('skill-demo-edit-focused-artwork'),
                            onPressed: () => Navigator.pop(context, _focusedArtwork),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text('Edit $_focusedArtwork artwork'),
                          ),
                        ],
                      ),
                      Text(
                         'Selected: $_focusedArtwork. Pickup places artwork in the arena; Equipped inspects the held state without firing. Casting, Projectile and Impact pause at the first corresponding observable arena event (when one occurs). These are not isolated animation tracks.',
                        style: const TextStyle(fontSize: 12),
                      ),
                       if (_previewEventMessage != null)
                         Text(
                           _previewEventMessage!,
                           key: const ValueKey('skill-demo-event-status'),
                           style: const TextStyle(fontSize: 12),
                         ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<int>(
                        valueListenable: SpriteRegistry.revision,
                        builder: (_, _, _) => Row(
                          children: [
                            _art(
                              'Casting',
                              _demo.match.skillLibrary
                                  .resolveVisual(skill, SkillVisualRole.casting)
                                  ?.spriteId,
                              'Not assigned',
                            ),
                            _art(
                              'Pickup',
                              skill.effectivePickupSpriteId ??
                                  PowerUpSprites.iconId(skill.displayKind),
                              'Built-in',
                            ),
                            _art(
                              'Equipped',
                              skill.effectiveHeldSpriteId ??
                                  PowerUpSprites.iconId(skill.displayKind),
                              'Built-in',
                            ),
                            _art(
                              'Projectile',
                              skill.projectileSpriteId ??
                                  PowerUpSprites.projectileArtworkId(
                                    skill.displayKind,
                                  ),
                              'Game default',
                            ),
                            _art(
                              'Impact',
                              _demo.match.skillLibrary
                                  .resolveVisual(skill, SkillVisualRole.impact)
                                  ?.spriteId,
                              'Game default',
                            ),
                          ],
                        ),
                      ),
                      SwitchListTile.adaptive(
                        key: const ValueKey('skill-demo-inspector'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Inspect effects'),
                        subtitle: const Text(
                          'Collision outlines and activation events',
                        ),
                        value: _inspect,
                        onChanged: (v) {
                          _inspectChosen = true;
                          setState(() => _inspect = v);
                          DevicePrefs.write('skill-demo-inspect', v);
                        },
                      ),
                      if (_inspect)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active sources: ${_demo.match.powerUps!.persistentEffects.handles.length} / transient events: ${_demo.match.powerUps!.persistentEffects.events.length}',
                                ),
                                Text(
                                  'Mechanical effects: ${_demo.match.powerUps!.activeCustomEffectCount} / budget rejections: ${_demo.match.powerUps!.compositionLimitHits}',
                                ),
                                const Text(
                                  'Yellow: physical areas, independent of artwork size.',
                                ),
                                for (final event
                                    in _demo
                                        .match
                                        .powerUps!
                                        .persistentEffects
                                        .history
                                        .reversed
                                        .take(8))
                                  Text(
                                    event,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (_demo
                                    .match
                                    .powerUps!
                                    .persistentEffects
                                    .history
                                    .isEmpty)
                                  const Text(
                                    'Use the skill or Incoming hit to inspect events.',
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        'Artwork references above show the first frame. The stage plays the actual move.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(
                              skill.trigger?.name ??
                                  (skill.baseKind.isGun
                                      ? 'Aimed fire'
                                      : 'On use'),
                            ),
                          ),
                          Chip(
                            label: Text(
                              skill.usesSpriteEffects(
                                    globalSprite:
                                        widget.effectMode ==
                                        EffectRenderMode.sprite,
                                  )
                                  ? 'Sprite effects'
                                  : 'Vector effects',
                            ),
                          ),
                          Chip(
                            label: Text(
                              skill.yell.isEmpty ? 'Default yell' : skill.yell,
                            ),
                          ),
                          Chip(label: Text('Sound: ${skill.soundCue}')),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Facing'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: true,
                                  label: Text('Right'),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text('Left'),
                                ),
                              ],
                              selected: {_demo.facingRight},
                              onSelectionChanged: (values) {
                                _facingChosen = true;
                                _demo.facingRight = values.first;
                                DevicePrefs.write(
                                  'skill-demo-facing',
                                  _demo.facingRight,
                                );
                                _reset();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<double>(
                            key: const ValueKey('skill-demo-speed'),
                            value: _demo.speed,
                            items: [
                              for (final value in [.25, .5, 1.0])
                                DropdownMenuItem(
                                  value: value,
                                  child: Text('${value}x'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              _speedChosen = true;
                              setState(() => _demo.speed = value);
                              DevicePrefs.write('skill-demo-speed', value);
                            },
                          ),
                        ],
                      ),
                      if (_demo.timeLimited)
                        const Text(
                          'Quick demo stops after 45 seconds. Use Live Arena for longer sequences.',
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('use-demo-skill'),
                            onPressed: _preparing ? null : _start,
                            icon: Icon(
                              _demo.started ? Icons.replay : Icons.play_arrow,
                            ),
                            label: Text(
                              _preparing
                                  ? 'Getting ready'
                                  : _demo.started
                                  ? 'Replay skill'
                                  : 'Use skill',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const ValueKey('pause-demo-skill'),
                          tooltip: _demo.playing ? 'Pause demo' : 'Resume demo',
                          onPressed:
                              !_preparing && _demo.started && _demo.elapsed < _demo.duration
                              ? _pause
                              : null,
                          icon: Icon(
                            _demo.playing ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          key: const ValueKey('reset-demo-skill'),
                          tooltip: 'Reset demo',
                          onPressed: _preparing ? null : _reset,
                          icon: const Icon(Icons.restart_alt),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      key: const ValueKey('demo-incoming-hit'),
                      onPressed: _preparing
                          ? null
                          : () async {
                                                             final generation = ++_previewGeneration;
                              // Incoming-hit inspection is a new preview action.
                              // Discard any prior event target and playback clock.
                              _ticker.stop();
                              _previous = null;
                              _awaitedPreviewEvent = null;
                              _previewEventMessage = null;
                              setState(() {
                                _preparing = true;
                                _error = null;
                              });
                              try {
                                await _preferences;
                                await _ensureArtwork();
                                if (!mounted || generation != _previewGeneration) return;
                                if (!_demo.started ||
                                    _demo.elapsed >= _demo.duration) {
                                  _heard.clear();
                                  _hits = _shots = _slashes = _blocks =
                                      _blasts = _pickups = 0;
                                }
                                                                 _demo.incomingHit();
                                _audio();
                                // A completed or paused preview must not
                                // leave an idle ticker running indefinitely.
                                if (_demo.playing) _ticker.start();
                                setState(() => _error = null);
                              } catch (error) {
                                if (mounted && generation == _previewGeneration) {
                                                                     _ticker.stop();
                                  _previous = null;
                                  _demo.stopPlayback();
                                  setState(
                                    () => _error =
                                        'Incoming-hit test could not start: $error',
                                  );
                                }
                              } finally {
                                if (mounted && generation == _previewGeneration) {
                                  setState(() => _preparing = false);
                                }
                              }
                            },
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Test incoming hit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _art(String label, String? id, String empty) {
    final image = id == null ? null : SpriteRegistry.frame(id);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11), maxLines: 1),
            const SizedBox(height: 4),
            Tooltip(
              message: id == null ? empty : SpriteRegistry.displayLabel(id),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: _focusedArtwork == label
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : null,
                ),
                child: image == null
                    ? Text(
                        empty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10),
                      )
                    : SkillArtworkTint.widget(
                        widget.skill.spriteTint,
                        ClipRect(
                          child: Opacity(
                            opacity: SpriteRegistry.imageOpacity(image),
                            child: Transform.scale(
                              scale: SpriteRegistry.imageScale(image),
                              child: RawImage(
                                image: image,
                                width: 46,
                                height: 46,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
