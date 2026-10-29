import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../sprites/presentation/sprites_screen.dart';
import '../domain/skill_library.dart';
import 'effect_placement_preview.dart';

String effectRoleLabel(SkillVisualRole role) => switch (role) {
  SkillVisualRole.casting => 'Casting',
  SkillVisualRole.muzzle => 'Muzzle flash',
  SkillVisualRole.trail => 'Projectile trail',
  SkillVisualRole.impact => 'Direct hit',
  SkillVisualRole.explosion => 'Explosion',
  SkillVisualRole.ground => 'Ground zone',
  SkillVisualRole.boundary => 'Arena boundary',
  SkillVisualRole.ownerStatus => 'Owner status / channel',
  SkillVisualRole.targetStatus => 'Target status',
  SkillVisualRole.block => 'Block',
  SkillVisualRole.breakage => 'Defense break',
  SkillVisualRole.expiry => 'Expiry',
  SkillVisualRole.discard => 'Discard',
};
String effectRoleHelp(SkillVisualRole role) => switch (role) {
  SkillVisualRole.casting => 'Plays on the caster when the move starts.',
  SkillVisualRole.muzzle => 'Flashes at the hand when an aimed weapon fires.',
  SkillVisualRole.trail =>
    'Follows a flying projectile; Loop works well for exhaust.',
  SkillVisualRole.impact => 'Plays when the skill hits an opponent.',
  SkillVisualRole.explosion =>
    'Plays on an explosion event. Artwork does not add explosion damage.',
  SkillVisualRole.ground =>
    'Replaces ground-zone artwork; collision and damage stay unchanged.',
  SkillVisualRole.boundary =>
    'Repeats along the real curved boundary samples, facing inward.',
  SkillVisualRole.ownerStatus =>
    'Follows an active buff or channel, ending with its activation.',
  SkillVisualRole.targetStatus =>
    'Follows a debuffed opponent until that status ends.',
  SkillVisualRole.block =>
    'Plays on a successful defensive block or reflection.',
  SkillVisualRole.breakage =>
    'Plays when the last armor, mirror or shield charge is used.',
  SkillVisualRole.expiry =>
    'Plays when a zone, channel or status ends; not on death/reset.',
  SkillVisualRole.discard =>
    'Plays when this equipped weapon is discarded or replaced.',
};

class SkillEffectsEditor extends StatefulWidget {
  const SkillEffectsEditor({
    super.key,
    required this.library,
    required this.skill,
    required this.tuning,
    required this.onChanged,
    required this.onPreview,
    this.roles,
  });
  final Set<SkillVisualRole>? roles;
  final SkillLibrary library;
  final SkillDefinition skill;
  final PowerUpConfig tuning;
  final void Function(SkillLibrary, Map<SkillVisualRole, SkillVisualBinding>)
  onChanged;
  final Future<void> Function(SkillLibrary, SkillDefinition) onPreview;

  @override
  State<SkillEffectsEditor> createState() => _SkillEffectsEditorState();
}

class _SkillEffectsEditorState extends State<SkillEffectsEditor> {
  SkillLibrary get library => widget.library;
  SkillDefinition get skill => widget.skill;
  PowerUpConfig get tuning => widget.tuning;
  void Function(SkillLibrary, Map<SkillVisualRole, SkillVisualBinding>)
  get onChanged => widget.onChanged;
  Future<void> Function(SkillLibrary, SkillDefinition) get onPreview =>
      widget.onPreview;
  int _group = 0;
  bool inGroup(SkillVisualRole role) => widget.roles != null
      ? widget.roles!.contains(role)
      : switch (_group) {
          0 => {
            SkillVisualRole.casting,
            SkillVisualRole.muzzle,
            SkillVisualRole.trail,
            SkillVisualRole.impact,
            SkillVisualRole.explosion,
          }.contains(role),
          1 => {
            SkillVisualRole.ground,
            SkillVisualRole.boundary,
            SkillVisualRole.ownerStatus,
            SkillVisualRole.targetStatus,
          }.contains(role),
          _ => {
            SkillVisualRole.block,
            SkillVisualRole.breakage,
            SkillVisualRole.expiry,
            SkillVisualRole.discard,
          }.contains(role),
        };
  bool available(SkillVisualRole role) {
    final flying = skill.isComposed
        ? skill.delivery == SkillDelivery.projectile ||
              skill.payloadSkillId != null
        : skill.baseKind.isGun &&
              !{
                PowerUpKind.energyWave,
                PowerUpKind.fireWall,
                PowerUpKind.flamethrower,
                PowerUpKind.sniperRifle,
                PowerUpKind.busterSword,
              }.contains(skill.baseKind);
    return switch (role) {
      SkillVisualRole.casting => true,
      SkillVisualRole.ground ||
      SkillVisualRole.boundary ||
      SkillVisualRole.ownerStatus ||
      SkillVisualRole.targetStatus ||
      SkillVisualRole.block ||
      SkillVisualRole.breakage ||
      SkillVisualRole.expiry ||
      SkillVisualRole.discard => persistentRoleAvailable(skill, role),
      SkillVisualRole.muzzle =>
        skill.isComposed
            ? skill.trigger == SkillTrigger.aimedFire
            : skill.baseKind.isGun,
      SkillVisualRole.trail => flying,
      SkillVisualRole.impact => skill.isComposed || skill.canDamage,
      SkillVisualRole.explosion =>
        (skill.explodesOnImpact && flying) ||
            (!skill.isComposed &&
                {
                  PowerUpKind.grenade,
                  PowerUpKind.rocketLauncher,
                  PowerUpKind.mine,
                  PowerUpKind.phaseMine,
                }.contains(skill.baseKind)),
    };
  }

  Future<void> _edit(
    BuildContext context,
    SkillVisualRole role,
    EffectDefinition? definition,
  ) async {
    if (definition == null && library.effects.length >= 256) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Effect library is full'),
          content: const Text(
            'Reuse an effect or delete an unused effect before adding another.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }
    final result = await showDialog<_EffectEdit>(
      context: context,
      builder: (_) => _EffectEditor(
        definition: definition,
        role: role,
        binding: skill.visualBindings[role],
        name: '${skill.name} ${effectRoleLabel(role)}',
        tint: skill.spriteTint,
        users: library
            .all(tuning)
            .where(
              (s) => s.visualBindings.values.any(
                (b) => b.effectId == definition?.id,
              ),
            )
            .map((s) => s.name)
            .toList(),
        onPreview: (edit) => onPreview(
          library.withEffect(edit.definition),
          skill.copyWith(
            visualBindings: {...skill.visualBindings, role: edit.binding!},
          ),
        ),
      ),
    );
    if (result != null) {
      onChanged(library.withEffect(result.definition), {
        ...skill.visualBindings,
        role: result.binding!,
      });
    }
  }

  Future<void> _library(BuildContext context) async {
    final updated = await showDialog<SkillLibrary>(
      context: context,
      builder: (_) => _EffectLibraryDialog(
        library: library,
        tuning: tuning,
        onPreview: (draft, definition) => onPreview(
          draft,
          skill.copyWith(
            visualBindings: {
              ...skill.visualBindings,
              SkillVisualRole.casting: SkillVisualBinding(
                effectId: definition.id,
              ),
            },
          ),
        ),
      ),
    );
    if (updated != null) onChanged(updated, skill.visualBindings);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Effects',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: () => _library(context),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Effect library'),
          ),
        ],
      ),
      const Text(
        'Shared artwork, separate from damage. Changes here are saved with this skill.',
      ),
      const SizedBox(height: 10),
      if (widget.roles == null)
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Attack')),
            ButtonSegment(value: 1, label: Text('Persistent')),
            ButtonSegment(value: 2, label: Text('Events')),
          ],
          showSelectedIcon: false,
          selected: {_group},
          onSelectionChanged: (values) => setState(() => _group = values.first),
        ),
      for (final role in SkillVisualRole.values.where(inGroup))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          effectRoleLabel(role),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reset ${effectRoleLabel(role)} to default',
                        onPressed: skill.visualBindings.containsKey(role)
                            ? () => onChanged(
                                library,
                                {...skill.visualBindings}..remove(role),
                              )
                            : null,
                        icon: const Icon(Icons.restart_alt, size: 20),
                      ),
                    ],
                  ),
                  Text(
                    effectRoleHelp(role),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!available(role))
                    Text(
                      role == SkillVisualRole.explosion
                          ? 'No explosion event. Enable Explosion on impact or use a native explosive.'
                          : 'Not emitted by the current behavior.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'effect-select-${role.name}-${skill.visualBindings[role]?.effectId}',
                    ),
                    isExpanded: true,
                    initialValue:
                        library.effects.containsKey(
                          skill.visualBindings[role]?.effectId,
                        )
                        ? skill.visualBindings[role]!.effectId
                        : '',
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(
                          role == SkillVisualRole.muzzle ||
                                  role == SkillVisualRole.trail
                              ? 'Game default'
                              : 'Default / legacy fallback',
                        ),
                      ),
                      for (final effect in library.effects.values)
                        DropdownMenuItem(
                          value: effect.id,
                          child: Row(
                            children: [
                              SpriteThumbnail(id: effect.spriteId, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  effect.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: !available(role)
                        ? null
                        : (value) {
                            final bindings = {...skill.visualBindings};
                            if (value == null || value.isEmpty) {
                              bindings.remove(role);
                            } else {
                              bindings[role] =
                                  skill.visualBindings[role]?.withEffect(
                                    value,
                                  ) ??
                                  SkillVisualBinding(effectId: value);
                            }
                            onChanged(library, bindings);
                          },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        key: ValueKey('new-effect-${role.name}'),
                        onPressed: available(role)
                            ? () => _edit(context, role, null)
                            : null,
                        icon: const Icon(Icons.add),
                        label: const Text('New'),
                      ),
                      TextButton.icon(
                        onPressed:
                            library.effects[skill
                                    .visualBindings[role]
                                    ?.effectId] ==
                                null
                            ? null
                            : () => _edit(
                                context,
                                role,
                                library.effects[skill
                                    .visualBindings[role]!
                                    .effectId],
                              ),
                        icon: const Icon(Icons.tune),
                        label: const Text('Edit'),
                      ),
                      TextButton.icon(
                        onPressed: available(role)
                            ? () => onPreview(library, skill)
                            : null,
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Preview'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _EffectEdit {
  const _EffectEdit(this.definition, this.binding);
  final EffectDefinition definition;
  final SkillVisualBinding? binding;
}

class _EffectEditor extends StatefulWidget {
  const _EffectEditor({
    this.definition,
    this.binding,
    this.role,
    required this.name,
    this.tint = 0xffffffff,
    this.users = const [],
    required this.onPreview,
  });
  final EffectDefinition? definition;
  final SkillVisualBinding? binding;
  final SkillVisualRole? role;
  final String name;
  final int tint;
  final List<String> users;
  final Future<void> Function(_EffectEdit) onPreview;
  @override
  State<_EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<_EffectEditor> {
  late final id =
      widget.definition?.id ??
      'effect.custom.${DateTime.now().microsecondsSinceEpoch}';
  late final name = TextEditingController(
    text: widget.definition?.name ?? widget.name,
  );
  late String? sprite = widget.definition?.spriteId;
  late EffectPlayback playback =
      widget.definition?.playback ??
      (widget.role == SkillVisualRole.trail
          ? EffectPlayback.loop
          : EffectPlayback.once);
  late bool fixed = widget.definition?.durationSeconds != null;
  late EffectAttachment attachment =
      widget.binding?.attachment ?? EffectAttachment.automatic;
  late EffectFacing facing = widget.binding?.facing ?? EffectFacing.upright;
  late int? tint = widget.binding?.tint;
  late final numbers = <String, TextEditingController>{
    'sharedSize': TextEditingController(
      text: '${widget.definition?.scale ?? 1}',
    ),
    'size': TextEditingController(text: '${widget.binding?.scale ?? 1}'),
    'duration': TextEditingController(
      text:
          '${widget.definition?.durationSeconds ?? (widget.role == SkillVisualRole.muzzle ? .12 : .5)}',
    ),
    'x': TextEditingController(text: '${widget.binding?.offsetX ?? 0}'),
    'y': TextEditingController(text: '${widget.binding?.offsetY ?? 0}'),
    'rotation': TextEditingController(
      text: '${widget.binding?.rotationDegrees ?? 0}',
    ),
  };
  late double sharedOpacity = widget.definition?.opacity ?? 1;
  late double opacity = widget.binding?.opacity ?? 1;
  String? error;
  double _previewProgress = 0;
  @override
  void initState() {
    super.initState();
    PowerUpSprites.load();
    if (widget.definition == null && widget.role == SkillVisualRole.muzzle) {
      fixed = true;
    }
  }

  @override
  void dispose() {
    name.dispose();
    for (final controller in numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double number(String key, String label, double min, double max) {
    final value = double.tryParse(numbers[key]!.text);
    if (value == null || !value.isFinite || value < min || value > max) {
      throw FormatException('$label must be between $min and $max.');
    }
    return value;
  }

  _EffectEdit collect() {
    if (name.text.trim().isEmpty || name.text.trim().length > 80) {
      throw const FormatException(
        'Enter an effect name (up to 80 characters).',
      );
    }
    if (sprite == null || !SpriteRegistry.has(sprite!)) {
      throw const FormatException(
        'Choose a loaded sprite before saving or previewing.',
      );
    }
    double? duration;
    if (playback == EffectPlayback.natural) {
      duration =
          SpriteRegistry.frameCount(sprite!) *
          SpriteRegistry.stepsPerFrame(sprite!) /
          60;
      if (duration > 10) {
        throw const FormatException(
          'Natural animation is longer than 10 seconds. Speed up the sprite or choose a fitted duration.',
        );
      }
      duration = math.max(1 / 60, duration);
    } else if (fixed) {
      duration = number('duration', 'Duration', .1, 10);
    }
    final definition = EffectDefinition(
      id: id,
      name: name.text.trim(),
      spriteId: sprite!,
      playback: playback,
      durationSeconds: duration,
      scale: number('sharedSize', 'Shared size', .1, 4),
      opacity: sharedOpacity,
    );
    final binding = widget.role == null
        ? null
        : SkillVisualBinding(
            effectId: id,
            scale: number('size', 'Size', .1, 4),
            opacity: opacity,
            attachment: attachment,
            facing: facing,
            offsetX: number('x', 'Forward offset', -5, 5),
            offsetY: number('y', 'Side offset', -5, 5),
            rotationDegrees: number('rotation', 'Rotation', -360, 360),
            tint: tint,
          );
    return _EffectEdit(definition, binding);
  }

  Future<void> act(bool preview) async {
    try {
      final edit = collect();
      setState(() => error = null);
      if (preview) {
        await widget.onPreview(edit);
      } else if (mounted) {
        Navigator.pop(context, edit);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e'.replaceFirst('FormatException: ', ''));
      }
    }
  }

  Widget row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 3, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(flex: 6, child: control),
      ],
    ),
  );
  Widget numeric(String key, String label, {String? suffix}) => row(
    label,
    TextField(
      key: ValueKey('effect-field-$key'),
      controller: numbers[key],
      onChanged: (_) => setState(() {}),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        suffixText: suffix,
      ),
    ),
  );
  double safeNumber(String key, double fallback) {
    final v = double.tryParse(numbers[key]!.text);
    return v != null && v.isFinite ? v : fallback;
  }

  Widget placementPreview() => ValueListenableBuilder<int>(
    valueListenable: SpriteRegistry.revision,
    builder: (_, _, _) => Column(
      children: [
        EffectPlacementPreview(
          key: const ValueKey('effect-placement-preview'),
          height: MediaQuery.viewInsetsOf(context).bottom > 0 ? 64 : 140,
          role: widget.role ?? SkillVisualRole.casting,
          progress: _previewProgress,
          effect: sprite == null
              ? null
              : ResolvedSkillEffect(
                  spriteId: sprite!,
                  scale:
                      safeNumber('sharedSize', 1).clamp(.1, 4) *
                      safeNumber('size', 1).clamp(.1, 4),
                  opacity: sharedOpacity * opacity,
                  tint: tint ?? widget.tint,
                  attachment: attachment,
                  facing: facing,
                  offsetX: safeNumber('x', 0).clamp(-5, 5),
                  offsetY: safeNumber('y', 0).clamp(-5, 5),
                  rotationDegrees: safeNumber('rotation', 0).clamp(-360, 360),
                  playback: playback,
                  durationSeconds: fixed ? safeNumber('duration', .5) : null,
                ),
        ),
        if (MediaQuery.viewInsetsOf(context).bottom == 0 &&
            sprite != null &&
            SpriteRegistry.frameCount(sprite!) > 1)
          row(
            'Animation frame',
            Slider(
              key: const ValueKey('effect-preview-frame'),
              value: _previewProgress,
              onChanged: (v) => setState(() => _previewProgress = v),
            ),
          ),
      ],
    ),
  );
  Widget adjustable(
    String key,
    String label,
    double min,
    double max, {
    String? suffix,
  }) => Column(
    children: [
      numeric(key, label, suffix: suffix),
      Slider(
        key: ValueKey('effect-slider-$key'),
        value: safeNumber(key, 0).clamp(min, max),
        min: min,
        max: max,
        label:
            '${safeNumber(key, 0).toStringAsFixed(key == 'rotation' ? 0 : 2)}${suffix ?? ''}',
        onChanged: (v) => setState(
          () =>
              numbers[key]!.text = v.toStringAsFixed(key == 'rotation' ? 0 : 2),
        ),
      ),
    ],
  );
  Widget percent(String label, double value, ValueChanged<double> changed) =>
      row(
        label,
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                onChanged: (v) => setState(() => changed(v)),
              ),
            ),
            Text('${(value * 100).round()}%'),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: widget.role == null ? 2 : 3,
    child: AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      title: Text(
        widget.role == null
            ? 'Edit effect'
            : '${effectRoleLabel(widget.role!)} effect',
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      content: SizedBox(
        width: 620,
        height: math.min(
          620,
          math.max(
            180,
            MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom -
                180,
          ),
        ),
        child: Column(
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TabBar(
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              tabs: [
                const Tab(text: 'Artwork'),
                if (widget.role != null) const Tab(text: 'Placement'),
                const Tab(text: 'Playback'),
              ],
            ),
            placementPreview(),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    children: [
                      if (widget.users.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            'Shared effect used by ${widget.users.join(', ')}. Artwork and playback edits affect every use. Placement is local to this skill.',
                          ),
                        ),
                      row(
                        'Name',
                        TextField(
                          key: const ValueKey('effect-name'),
                          controller: name,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: SpriteThumbnail(id: sprite, size: 48),
                        title: const Text('Sprite'),
                        subtitle: Text(
                          sprite == null
                              ? 'Choose artwork'
                              : SpriteRegistry.displayLabel(sprite!),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await selectSkillSprite(
                            context,
                            title: 'Effect sprite',
                            current: sprite,
                            includeBuiltIns: true,
                          );
                          if (mounted && picked != null) {
                            setState(
                              () => sprite = picked.isEmpty ? null : picked,
                            );
                          }
                        },
                      ),
                      adjustable(
                        'sharedSize',
                        'Shared size',
                        .1,
                        4,
                        suffix: 'x',
                      ),
                      percent(
                        'Shared opacity',
                        sharedOpacity,
                        (v) => sharedOpacity = v,
                      ),
                      const Text(
                        'Shared size/opacity combine with global, skill and sprite settings. Damage and hit areas stay unchanged.',
                      ),
                    ],
                  ),
                  if (widget.role != null)
                    ListView(
                      children: [
                        row(
                          'Attach to',
                          DropdownButtonFormField<EffectAttachment>(
                            key: const ValueKey('effect-attachment'),
                            isExpanded: true,
                            initialValue: attachment,
                            items: [
                              for (final item in effectAttachments(
                                widget.role!,
                              ))
                                DropdownMenuItem(
                                  value: item,
                                  child: Text(switch (item) {
                                    EffectAttachment.automatic =>
                                      'Role default',
                                    EffectAttachment.owner => 'Caster body',
                                    EffectAttachment.hand => 'Caster hand',
                                    EffectAttachment.target => 'Target body',
                                    EffectAttachment.impact => 'Impact point',
                                    EffectAttachment.projectile => 'Projectile',
                                  }),
                                ),
                            ],
                            onChanged: (v) => setState(() => attachment = v!),
                          ),
                        ),
                        adjustable('size', 'Local size', .1, 4, suffix: 'x'),
                        percent('Local opacity', opacity, (v) => opacity = v),
                        row(
                          'Use skill tint',
                          Switch(
                            value: tint == null,
                            onChanged: (v) =>
                                setState(() => tint = v ? null : widget.tint),
                          ),
                        ),
                        if (tint != null)
                          row(
                            'Tint',
                            OutlinedButton.icon(
                              icon: Icon(
                                Icons.palette_outlined,
                                color: Color(tint!),
                              ),
                              label: const Text('Choose'),
                              onPressed: () async {
                                final color = await showColorPicker(
                                  context,
                                  initialColor: Color(tint!),
                                  title: 'Effect tint',
                                );
                                if (color != null && mounted) {
                                  setState(() => tint = color.toARGB32());
                                }
                              },
                            ),
                          ),
                        row(
                          'Facing',
                          DropdownButtonFormField<EffectFacing>(
                            key: const ValueKey('effect-facing'),
                            isExpanded: true,
                            initialValue: facing,
                            items: const [
                              DropdownMenuItem(
                                value: EffectFacing.upright,
                                child: Text('Stay upright'),
                              ),
                              DropdownMenuItem(
                                value: EffectFacing.direction,
                                child: Text('Follow direction'),
                              ),
                              DropdownMenuItem(
                                value: EffectFacing.mirror,
                                child: Text('Mirror left/right'),
                              ),
                            ],
                            onChanged: (v) => setState(() => facing = v!),
                          ),
                        ),
                        adjustable('x', 'Forward offset', -5, 5, suffix: 'r'),
                        adjustable('y', 'Side offset', -5, 5, suffix: 'r'),
                        adjustable(
                          'rotation',
                          'Rotation',
                          -360,
                          360,
                          suffix: 'deg',
                        ),
                        const Text(
                          'Offsets are measured in ball radii along and across the attack direction. Placement does not change collision.',
                        ),
                      ],
                    ),
                  ListView(
                    children: [
                      row(
                        'Playback',
                        DropdownButtonFormField<EffectPlayback>(
                          key: const ValueKey('effect-playback'),
                          isExpanded: true,
                          initialValue: playback,
                          items: const [
                            DropdownMenuItem(
                              value: EffectPlayback.once,
                              child: Text('Fit once'),
                            ),
                            DropdownMenuItem(
                              value: EffectPlayback.loop,
                              child: Text('Loop'),
                            ),
                            DropdownMenuItem(
                              value: EffectPlayback.holdLast,
                              child: Text('Play and hold'),
                            ),
                            DropdownMenuItem(
                              value: EffectPlayback.natural,
                              child: Text('Natural length'),
                            ),
                          ],
                          onChanged: (v) => setState(() => playback = v!),
                        ),
                      ),
                      if (playback != EffectPlayback.natural) ...[
                        row(
                          'Fixed lifetime',
                          Switch(
                            value: fixed,
                            onChanged: (v) => setState(() => fixed = v),
                          ),
                        ),
                        if (fixed)
                          numeric('duration', 'Duration', suffix: 's')
                        else
                          const Text(
                            'Uses the existing event lifetime. Trails follow their projectile; Loop is recommended for continuous exhaust.',
                          ),
                      ] else
                        Text(
                          sprite == null
                              ? 'Choose a sprite to calculate its natural duration.'
                              : 'Natural duration: ${(SpriteRegistry.frameCount(sprite!) * SpriteRegistry.stepsPerFrame(sprite!) / 60).toStringAsFixed(2)} s',
                        ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fit once stretches playback across the lifetime. Loop uses sheet speed. Play and hold keeps the final frame. Natural length ends after one animation.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          onPressed: () => act(true),
          icon: const Icon(Icons.science_outlined),
          label: const Text('Preview'),
        ),
        FilledButton(
          onPressed: () => act(false),
          child: const Text('Use effect'),
        ),
      ],
    ),
  );
}

class _EffectLibraryDialog extends StatefulWidget {
  const _EffectLibraryDialog({
    required this.library,
    required this.tuning,
    required this.onPreview,
  });
  final SkillLibrary library;
  final PowerUpConfig tuning;
  final Future<void> Function(SkillLibrary, EffectDefinition) onPreview;
  @override
  State<_EffectLibraryDialog> createState() => _EffectLibraryDialogState();
}

class _EffectLibraryDialogState extends State<_EffectLibraryDialog> {
  late SkillLibrary library = widget.library;
  String query = '';
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<String> users(String id) => library
      .all(widget.tuning)
      .where((s) => s.visualBindings.values.any((b) => b.effectId == id))
      .map((s) => s.name)
      .toList();
  Future<void> edit([EffectDefinition? definition]) async {
    final result = await showDialog<_EffectEdit>(
      context: context,
      builder: (_) => _EffectEditor(
        definition: definition,
        name: 'New effect',
        users: definition == null ? [] : users(definition.id),
        onPreview: (edit) => widget.onPreview(
          library.withEffect(edit.definition),
          edit.definition,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => library = library.withEffect(result.definition));
    }
  }

  @override
  Widget build(BuildContext context) {
    final effects =
        library.effects.values
            .where((e) => e.name.toLowerCase().contains(query.toLowerCase()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return AlertDialog(
      title: const Text('Effect library'),
      content: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .55,
        child: Column(
          children: [
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: 'Search effects',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear effect search',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          search.clear();
                          setState(() => query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
            Expanded(
              child: effects.isEmpty
                  ? Center(
                      child: Text(
                        library.effects.isEmpty
                            ? 'No effects. Create one to reuse across skills.'
                            : 'No effects match your search.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: effects.length,
                      itemBuilder: (_, i) {
                        final effect = effects[i];
                        final used = users(effect.id);
                        return ListTile(
                          leading: SpriteThumbnail(id: effect.spriteId),
                          title: Text(effect.name),
                          subtitle: Text(
                            used.isEmpty
                                ? 'Not assigned'
                                : 'Used by ${used.join(', ')}',
                          ),
                          onTap: () => edit(effect),
                          trailing: IconButton(
                            tooltip: used.isEmpty
                                ? 'Delete ${effect.name}'
                                : 'Remove skill bindings before deleting',
                            onPressed: used.isNotEmpty
                                ? null
                                : () => setState(
                                    () => library = library.withoutEffect(
                                      effect.id,
                                    ),
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: library.effects.length >= 256 ? null : edit,
          icon: const Icon(Icons.add),
          label: const Text('New effect'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, library),
          child: const Text('Use library'),
        ),
      ],
    );
  }
}
