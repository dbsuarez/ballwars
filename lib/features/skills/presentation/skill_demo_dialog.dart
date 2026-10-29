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
  bool _inspect = false;
  bool _preparing = false;
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
    _restoreSpeed();
    PowerUpSprites.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _restoreSpeed() async {
    final speed = double.tryParse(
      await DevicePrefs.read('skill-demo-speed') ?? '',
    );
    if (mounted && !_speedChosen && {.25, .5, 1.0}.contains(speed)) {
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

  void _tick(Duration time) {
    final old = _previous;
    _previous = time;
    if (old == null) return;
    try {
      _demo.step((time - old).inMicroseconds / 1000000);
      _audio();
      if (!_demo.playing) _ticker.stop();
      if (mounted) setState(() {});
    } catch (error) {
      _ticker.stop();
      setState(() {
        _demo.playing = false;
        _error = 'Demo could not continue: $error';
      });
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
    _ticker.stop();
    _previous = null;
    _heard.clear();
    _hits = _shots = _slashes = _blocks = _blasts = _pickups = 0;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      await _ensureArtwork();
      if (!mounted) return;
      _demo.activate();
      _audio();
      setState(() => _error = null);
      _ticker.start();
    } catch (error) {
      if (mounted) setState(() => _error = 'Demo could not start: $error');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _reset() {
    _ticker.stop();
    _previous = null;
    setState(() {
      _demo.reset();
      _error = null;
    });
  }

  void _pause() {
    setState(() => _demo.playing = !_demo.playing);
    _previous = null;
    _demo.playing ? _ticker.start() : _ticker.stop();
  }

  @override
  void dispose() {
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
                      onPressed: () => setState(() => _sound = !_sound),
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
                      LayoutBuilder(
                        builder: (context, bounds) => Center(
                          child: SizedBox.square(
                            dimension: math.min(
                              bounds.maxWidth,
                              math.max(180, math.min(400, size.height * .44)),
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
                      const SizedBox(height: 10),
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
                              'Equipped',
                              skill.iconSpriteId ??
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
                        onChanged: (v) => setState(() => _inspect = v),
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
                                _demo.facingRight = values.first;
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
                              _demo.started && _demo.elapsed < _demo.duration
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
                              setState(() => _preparing = true);
                              try {
                                await _ensureArtwork();
                                if (!mounted) return;
                                if (!_demo.started ||
                                    _demo.elapsed >= _demo.duration) {
                                  _heard.clear();
                                  _hits = _shots = _slashes = _blocks =
                                      _blasts = _pickups = 0;
                                }
                                _demo.incomingHit();
                                _audio();
                                _previous = null;
                                if (!_ticker.isActive) _ticker.start();
                                setState(() => _error = null);
                              } catch (error) {
                                _ticker.stop();
                                if (mounted) {
                                  setState(
                                    () => _error =
                                        'Incoming-hit test could not start: $error',
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _preparing = false);
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
