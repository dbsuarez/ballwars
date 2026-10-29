import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/sprites/sprite_registry.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/canvas_action_glyph.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../settings/presentation/power_up_test_screen.dart';
import '../../settings/presentation/app_settings_scope.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/skill_library.dart';
import 'grip_preview_dialog.dart';
import 'skill_demo_dialog.dart';
import '../../sprites/presentation/sprites_screen.dart';
import 'skill_artwork_tint.dart';

class SkillManagementScreen extends StatefulWidget {
  const SkillManagementScreen({
    super.key,
    required this.initial,
    required this.tuning,
    this.onSave,
    this.initialEffectVisuals = EffectRenderMode.sprite,
  });

  final SkillLibrary initial;
  final PowerUpConfig tuning;

  /// Global: the default effect visuals (Sprite or Vector) for skills set to "Use global setting".
  /// Saved by the caller from [SkillManagementResult.effectVisuals].
  final EffectRenderMode initialEffectVisuals;
  final Future<void> Function(SkillManagementResult)? onSave;

  @override
  State<SkillManagementScreen> createState() => _SkillManagementScreenState();
}

class SkillManagementResult {
  const SkillManagementResult({
    required this.library,
    required this.tuning,
    required this.effectVisuals,
  });

  final SkillLibrary library;
  final PowerUpConfig tuning;

  /// The default effect visuals chosen in Global (projectiles, explosions and freeze together).
  final EffectRenderMode effectVisuals;
}

class _SkillEditResult {
  const _SkillEditResult(this.skill, this.rarity);

  final SkillDefinition skill;
  final PowerUpRarity? rarity;
}

class _SkillManagementScreenState extends State<SkillManagementScreen> {
  late SkillLibrary _library = widget.initial;
  late PowerUpConfig _tuning = widget.tuning;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportLibrary() async {
    final source = const JsonEncoder.withIndent(
      '  ',
    ).convert(_library.toJson());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export skill library'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(source)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            key: const ValueKey('copy-skill-library-json'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: source));
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy JSON'),
          ),
        ],
      ),
    );
  }

  Future<void> _importLibrary() async {
    final controller = TextEditingController();
    String? error;
    final imported = await showDialog<SkillLibrary>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Import skill library'),
          content: SizedBox(
            width: 620,
            child: TextField(
              key: const ValueKey('skill-library-json-input'),
              controller: controller,
              minLines: 10,
              maxLines: 18,
              decoration: InputDecoration(
                hintText: 'Paste versioned skill-library JSON',
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-skill-library-import'),
              onPressed: () {
                try {
                  Navigator.pop(
                    context,
                    SkillLibrary.importJson(controller.text),
                  );
                } on FormatException catch (exception) {
                  refresh(() => error = exception.message);
                }
              },
              child: const Text('Import draft'),
            ),
          ],
        ),
      ),
    );
    if (imported == null || !mounted) return;
    setState(() => _library = imported);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Imported as a draft. Save to publish it.')),
    );
  }

  /// A built-in's tier lives in the tuning (`tier.<kind>`); a custom skill keeps its own, so editing it
  /// never changes the built-in it is based on. An unchanged custom tier keeps following its base kind.
  (SkillDefinition, PowerUpConfig) _applyRarity(
    SkillDefinition original,
    _SkillEditResult edited,
  ) {
    final rarity = edited.rarity;
    if (rarity == null) return (edited.skill, _tuning);
    if (!edited.skill.custom) {
      return (edited.skill, _tuning.withRarity(original.baseKind, rarity));
    }
    if (rarity == SkillLibrary.rarityOf(original, _tuning)) {
      return (edited.skill, _tuning);
    }
    return (SkillLibrary.withOwnRarity(edited.skill, rarity, _tuning), _tuning);
  }

  Future<void> _edit(SkillDefinition skill) async {
    final edited = await showModalBottomSheet<_SkillEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SkillEditor(
        skill: skill,
        library: _library,
        tuning: _tuning,
        rarity: SkillLibrary.rarityOf(skill, _tuning),
        onSave: widget.onSave == null
            ? null
            : (edited) async {
                final (definition, tuning) = _applyRarity(skill, edited);
                final library = _library.withDefinition(definition, tuning);
                await widget.onSave!(
                  SkillManagementResult(
                    library: library,
                    tuning: tuning,
                    effectVisuals: _effectVisuals,
                  ),
                );
                if (mounted) {
                  setState(() {
                    _library = library;
                    _tuning = tuning;
                  });
                }
              },
      ),
    );
    if (edited == null || !mounted) return;
    setState(() {
      final (definition, tuning) = _applyRarity(skill, edited);
      _tuning = tuning;
      _library = _library.withDefinition(definition, _tuning);
    });
  }

  Future<void> _duplicate(SkillDefinition source) async {
    final controller = TextEditingController(text: '${source.name} Variant');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'New skill name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    final copy = _library.duplicate(source, name);
    setState(() => _library = _library.withDefinition(copy, _tuning));
    await _edit(copy);
  }

  Future<void> _create() async {
    final name = TextEditingController();
    var carrier = PowerUpKind.pistol;
    final draft = await showDialog<SkillDefinition>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Create new skill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: 'Skill name'),
                ),
                DropdownButtonFormField<PowerUpKind>(
                  isExpanded: true,
                  initialValue: carrier,
                  decoration: const InputDecoration(
                    labelText: 'Visual template',
                    helperText:
                        'Uses this artwork. Your new skill is added separately.',
                  ),
                  items: [
                    for (final kind in PowerUpKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Row(
                          children: [
                            PowerUpIcon(kind, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                kind.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => refresh(() => carrier = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = name.text.trim();
                if (value.isNotEmpty) {
                  Navigator.pop(context, _library.create(value, carrier));
                }
              },
              child: const Text('Build skill'),
            ),
          ],
        ),
      ),
    );
    if (draft == null || !mounted) return;
    setState(() => _library = _library.withDefinition(draft, _tuning));
    await _edit(draft);
  }

  Widget _list(
    bool custom, {
    String? category,
    List<Widget> headers = const [],
  }) {
    final query = _query.trim().toLowerCase();
    final skills =
        _library
            .all(_tuning)
            .where((skill) => skill.custom == custom)
            .where(
              (skill) =>
                  query.isNotEmpty ||
                  category == null ||
                  _categoryOf(skill) == category,
            )
            .where(
              (skill) =>
                  query.isEmpty ||
                  skill.name.toLowerCase().contains(query) ||
                  skill.baseKind.label.toLowerCase().contains(query),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final visibleHeaders = headers;
    if (skills.isEmpty && visibleHeaders.isEmpty) {
      return AnimatedEmptyState(
        icon: custom ? Icons.auto_awesome_outlined : Icons.search_off,
        message: custom
            ? 'No custom skills yet. Duplicate a built-in skill to create one.'
            : 'No matching skills.',
      );
    }
    final descriptionTuning = _library.applyTo(_tuning);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: skills.length + visibleHeaders.length,
      itemBuilder: (context, index) {
        if (index < visibleHeaders.length) return visibleHeaders[index];
        final skill = skills[index - visibleHeaders.length];
        final tierLabel =
            skill.resolvedCategory == SkillCategory.trap ||
                skill.resolvedCategory == SkillCategory.arenaTrap
            ? 'Special'
            : SkillLibrary.rarityOf(skill, _tuning)!.label;
        final details = <String>[
          tierLabel,
          if (skill.custom) skill.enabled ? 'Active' : 'Inactive',
          if (skill.arsenalDamage != null) '${skill.arsenalDamage} life',
          if (skill.allOutDamage != null) '${skill.allOutDamage} lines',
          if (skill.durationSeconds != null) '${skill.durationSeconds}s',
          if (skill.projectileCount != null)
            '${skill.projectileCount} projectiles',
          if (skill.maxBounces != null) '${skill.maxBounces} bounce',
        ];
        // The skill's own description (custom or an edited built-in), else the generated note.
        final note = skill.description.isNotEmpty
            ? skill.description
            : skill.custom && skill.enabled
            ? 'Independent skill using ${skill.baseKind.label} artwork'
            : skill.custom
            ? null
            : powerUpDescription(
                skill.baseKind,
                arsenal: true,
                config: descriptionTuning,
              );
        return Card(
          child: ListTile(
            minVerticalPadding: 12,
            leading: PowerUpIcon(
              skill.baseKind,
              size: 38,
              tint: skill.spriteTint,
              spriteId: skill.iconSpriteId,
              useSettingsArtwork: false,
            ),
            title: Text(
              skill.name,
              key: ValueKey('skill-name-${skill.id}'),
              style: TextStyle(
                color:
                    skill.resolvedCategory == SkillCategory.trap ||
                        skill.resolvedCategory == SkillCategory.arenaTrap
                    ? const Color(0xFFFFD54F)
                    : SkillLibrary.rarityOf(skill, _tuning)?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${_categoryLabel(skill.resolvedCategory)}'
              '${details.isEmpty ? "" : " • ${details.join(" • ")}"}'
              '${note == null ? "" : "\n$note"}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: note != null,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit(skill);
                if (value == 'duplicate') _duplicate(skill);
                if (value == 'delete') {
                  setState(() => _library = _library.removeCustom(skill.id));
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
                if (skill.custom)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            onTap: () => _edit(skill),
          ),
        );
      },
    );
  }

  static String _categoryOf(SkillDefinition skill) =>
      switch (skill.resolvedCategory) {
        SkillCategory.weapon => 'Weapons',
        SkillCategory.powerUp => 'Power-ups',
        SkillCategory.trap || SkillCategory.arenaTrap => 'Traps',
      };

  static String _categoryLabel(SkillCategory category) => switch (category) {
    SkillCategory.weapon => 'Weapon',
    SkillCategory.powerUp => 'Power-up',
    SkillCategory.trap => 'Trap',
    SkillCategory.arenaTrap => 'Arena trap',
  };

  static const _arenaTrapFields = <String, List<String>>{
    'Gravity Well': ['gravityWellForce'],
    'Quicksand': ['quicksandSlowdown', 'quicksandDamage', 'quicksandLines'],
    'Vine Snare': ['vineSnareDuration'],
    'Laser Gate': ['laserGateDamage', 'laserGateLines'],
  };

  static const _arenaTrapIcons = <String, IconData>{
    'Gravity Well': Icons.blur_circular,
    'Quicksand': Icons.landscape_outlined,
    'Vine Snare': Icons.grass,
    'Laser Gate': Icons.horizontal_rule,
  };

  Future<void> _editArenaTrap(String trapName) async {
    const sharedIds = [
      'arenaTrapsEnabled',
      'arenaTrapInterval',
      'arenaTrapDuration',
    ];
    final ids = {...sharedIds, ...?_arenaTrapFields[trapName]};
    final fields = PowerUpConfig.fields
        .where((field) => ids.contains(field.id))
        .toList();
    final controllers = <String, TextEditingController>{
      for (final field in fields.where(
        (field) => field.id != 'arenaTrapsEnabled',
      ))
        field.id: TextEditingController(
          text: _formatTuning(field, _tuning.value(field.id)),
        ),
    };
    var enabled = _tuning.arenaTrapsEnabled;
    var draft = _tuning;
    final result = await showDialog<PowerUpConfig>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Text('$trapName settings'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    key: const ValueKey('arena-traps-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable automatic arena traps'),
                    subtitle: const Text(
                      'Arena fixtures spawn automatically and are never collectibles.',
                    ),
                    value: enabled,
                    onChanged: (value) => refresh(() => enabled = value),
                  ),
                  const Divider(),
                  for (final field in fields.where(
                    (field) => field.id != 'arenaTrapsEnabled',
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        key: ValueKey('arena-trap-${field.id}'),
                        controller: controllers[field.id],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,4}'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: field.label,
                          suffixText: _tuningUnit(field),
                          helperText:
                              'Default ${_formatTuning(field, field.defaultValue)} • ${_formatTuning(field, field.min)}–${_formatTuning(field, field.max)}',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('restore-arena-trap-defaults'),
              onPressed: () {
                refresh(() {
                  enabled = true;
                  for (final field in fields.where(
                    (field) => field.id != 'arenaTrapsEnabled',
                  )) {
                    controllers[field.id]!.text = _formatTuning(
                      field,
                      field.defaultValue,
                    );
                  }
                });
              },
              child: const Text('Restore defaults'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('save-arena-trap-config'),
              onPressed: () {
                draft = draft.withValue('arenaTrapsEnabled', enabled ? 1 : 0);
                for (final field in fields.where(
                  (field) => field.id != 'arenaTrapsEnabled',
                )) {
                  final value = num.tryParse(controllers[field.id]!.text);
                  if (value != null) draft = draft.withValue(field.id, value);
                }
                Navigator.pop(context, draft);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    // Let the dialog's reverse transition detach its text fields before their
    // controllers are released.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final controller in controllers.values) {
      controller.dispose();
    }
    if (result != null && mounted) setState(() => _tuning = result);
  }

  static String _formatTuning(TuningField field, num value) {
    if (field.integer) return '${value.round()}';
    return value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _tuningUnit(TuningField field) => switch (field.unit) {
    TuningUnit.seconds => 'seconds',
    TuningUnit.percent => '%',
    TuningUnit.ratio => 'ratio',
    TuningUnit.count => '',
  };

  Widget _arenaTrapCard(String trapName) => Card(
    key: ValueKey('arena-trap-card-$trapName'),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: ListTile(
      minVerticalPadding: 14,
      leading: Icon(
        _arenaTrapIcons[trapName] ?? Icons.warning_amber_rounded,
        color: const Color(0xFFFFD54F),
        size: 34,
      ),
      title: Text(trapName, style: TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        'Arena • ${_tuning.arenaTrapsEnabled ? "Enabled" : "Disabled"} • '
        'every ${_formatTuning(PowerUpConfig.fields.firstWhere((f) => f.id == "arenaTrapInterval"), _tuning.value("arenaTrapInterval"))}s • '
        '${_formatTuning(PowerUpConfig.fields.firstWhere((f) => f.id == "arenaTrapDuration"), _tuning.value("arenaTrapDuration"))}s active\n'
        'Arena fixture — never a collectible.',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _editArenaTrap(trapName),
    ),
  );

  late EffectRenderMode _effectVisuals = widget.initialEffectVisuals;

  late final TextEditingController _calloutText = TextEditingController(
    text: _formatSeconds(_library.calloutSeconds),
  );
  late final TextEditingController _shakeText = TextEditingController(
    text: _formatSeconds(_library.screenShake),
  );
  late final TextEditingController _weaponScaleText = TextEditingController(
    text: _formatSeconds(_library.weaponDisplayScale),
  );
  late final TextEditingController _pickupScaleText = TextEditingController(
    text: _formatSeconds(_library.pickupDisplayScale),
  );
  late final TextEditingController _effectScaleText = TextEditingController(
    text: _formatSeconds(_library.effectDisplayScale),
  );

  /// "Apply to all skills": after a confirmation, writes the value into every skill's own field
  /// ([SkillLibrary.applyToAll] through [apply]). Saved with Save library like any edit.
  Future<void> _applyToAll(
    String shown,
    SkillLibrary Function(SkillLibrary library) apply,
  ) async {
    final count = _library.all(_tuning).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to all skills'),
        content: Text(
          "Set $shown on all $count skills? This changes each skill's own value."
          ' Built-in skills you have not edited yet become individually edited skills, so Edit power-up numbers (Legacy) will no longer change them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const ValueKey('apply-all-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _library = apply(_library));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Set $shown on all $count skills. Save library to keep it.',
          ),
        ),
      );
  }

  /// One global setting: a number for every skill, and "Let each skill set its own".
  Widget _globalCard({
    required String label,
    required Key fieldKey,
    required Key switchKey,
    required TextEditingController controller,
    required String suffix,
    required double min,
    required double max,
    required bool skillsSetOwn,
    required String ownNote,
    required String globalNote,
    required void Function(double value) onValue,
    required void Function(bool value) onSkillsSetOwn,
    required Key applyKey,
    required String Function(double value) shown,
    required SkillLibrary Function(SkillLibrary library, double value)
    applyToAll,
  }) {
    final c = BallWarsColors.of(context);
    final typed = double.tryParse(controller.text.trim());
    final error = typed == null || typed < min || typed > max
        ? 'Enter ${_formatSeconds(min)} to ${_formatSeconds(max)}'
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    label,
                    style: AppText.ui(14, FontWeight.w600, color: c.text),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: TextField(
                    key: fieldKey,
                    controller: controller,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      suffixText: suffix,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                    onChanged: (text) {
                      final value = double.tryParse(text.trim());
                      setState(() {
                        if (value != null && value >= min && value <= max) {
                          onValue(value);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: switchKey,
              contentPadding: EdgeInsets.zero,
              title: const Text('Let each skill set its own'),
              subtitle: Text(skillsSetOwn ? ownNote : globalNote),
              value: skillsSetOwn,
              onChanged: (value) => setState(() => onSkillsSetOwn(value)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  key: applyKey,
                  onPressed: error != null
                      ? null
                      : () => _applyToAll(
                          shown(typed!),
                          (library) => applyToAll(library, typed),
                        ),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Apply to all skills'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatSeconds(double seconds) =>
      seconds.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  /// Settings for every skill at once. Saved with the library (Save library).
  Widget _globalSettings() {
    final c = BallWarsColors.of(context);
    return ListView(
      key: const ValueKey('skill-global-settings'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Settings for every skill. Saved with Save library.',
          style: AppText.ui(12, FontWeight.w500, color: c.muted, height: 1.35),
        ),
        const SizedBox(height: 12),
        _globalCard(
          label: 'Callout duration',
          fieldKey: const ValueKey('global-callout-seconds'),
          switchKey: const ValueKey('skills-set-callout'),
          controller: _calloutText,
          suffix: 's',
          min: 0.25,
          max: 10,
          skillsSetOwn: _library.skillsSetCallout,
          ownNote:
              'Each skill uses its own callout duration (Callouts & Sounds). This value is not used.',
          globalNote:
              'Every skill uses this duration. The callout duration in each skill is disabled.',
          onValue: (v) => _library = _library.withGlobal(calloutSeconds: v),
          onSkillsSetOwn: (v) =>
              _library = _library.withGlobal(skillsSetCallout: v),
          applyKey: const ValueKey('apply-all-callout-seconds'),
          shown: (v) => '${_formatSeconds(v)} s',
          applyToAll: (library, v) =>
              library.applyToAll(_tuning, calloutSeconds: v),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        'Default effect visuals',
                        style: AppText.ui(14, FontWeight.w600, color: c.text),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: DropdownButtonFormField<EffectRenderMode>(
                        key: const ValueKey('global-effect-visuals'),
                        isExpanded: true,
                        initialValue: _effectVisuals,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final mode in EffectRenderMode.values)
                            DropdownMenuItem(
                              value: mode,
                              child: Text(mode.label),
                            ),
                        ],
                        onChanged: (mode) {
                          if (mode != null) {
                            setState(() => _effectVisuals = mode);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sprite artwork or the lightweight vector look for projectiles, explosions and freeze. '
                  'Used by skills whose Effect visuals is "Use global setting"; a skill set to Sprite or Vector '
                  'keeps its own. Players can also pick their own in Match Setup > Appearance.',
                  style: AppText.ui(
                    12,
                    FontWeight.w500,
                    color: c.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        _globalCard(
          label: 'Screen shake',
          fieldKey: const ValueKey('global-screen-shake'),
          switchKey: const ValueKey('skills-set-screen-shake'),
          controller: _shakeText,
          suffix: '0-1',
          min: 0,
          max: 1,
          skillsSetOwn: _library.skillsSetScreenShake,
          ownNote:
              'Each skill uses its own impact shake (Appearance). This value is not used.',
          globalNote:
              'Every skill uses this shake. The screen shake in each skill is disabled.',
          onValue: (v) => _library = _library.withGlobal(screenShake: v),
          onSkillsSetOwn: (v) =>
              _library = _library.withGlobal(skillsSetScreenShake: v),
          applyKey: const ValueKey('apply-all-screen-shake'),
          shown: _formatSeconds,
          applyToAll: (library, v) =>
              library.applyToAll(_tuning, screenShake: v),
        ),
        _globalCard(
          label: 'Equipped artwork size',
          fieldKey: const ValueKey('global-weapon-display-scale'),
          switchKey: const ValueKey('skills-set-weapon-display-scale'),
          controller: _weaponScaleText,
          suffix: 'x',
          min: 0.25,
          max: 3,
          skillsSetOwn: _library.skillsSetWeaponDisplayScale,
          ownNote:
              'Each weapon uses its own equipped display scale (Appearance). This value is not used.',
          globalNote:
              'Every weapon in hand is drawn at this size. The equipped display scale in each skill is disabled.',
          onValue: (v) => _library = _library.withGlobal(weaponDisplayScale: v),
          onSkillsSetOwn: (v) =>
              _library = _library.withGlobal(skillsSetWeaponDisplayScale: v),
          applyKey: const ValueKey('apply-all-weapon-display-scale'),
          shown: (v) => '${_formatSeconds(v)}x',
          applyToAll: (library, v) =>
              library.applyToAll(_tuning, weaponDisplayScale: v),
        ),
        _globalCard(
          label: 'Pickup artwork size',
          fieldKey: const ValueKey('global-pickup-display-scale'),
          switchKey: const ValueKey('skills-set-pickup-display-scale'),
          controller: _pickupScaleText,
          suffix: 'x',
          min: 0.25,
          max: 3,
          skillsSetOwn: _library.skillsSetPickupDisplayScale,
          ownNote:
              'Each skill uses its own pickup artwork scale (Appearance). This value is not used.',
          globalNote:
              'Every pickup in the arena is drawn at this size. The pickup artwork scale in each skill is disabled.',
          onValue: (v) => _library = _library.withGlobal(pickupDisplayScale: v),
          onSkillsSetOwn: (v) =>
              _library = _library.withGlobal(skillsSetPickupDisplayScale: v),
          applyKey: const ValueKey('apply-all-pickup-display-scale'),
          shown: (v) => '${_formatSeconds(v)}x',
          applyToAll: (library, v) =>
              library.applyToAll(_tuning, pickupDisplayScale: v),
        ),
        _globalCard(
          label: 'Effect artwork size',
          fieldKey: const ValueKey('global-effect-display-scale'),
          switchKey: const ValueKey('skills-set-effect-display-scale'),
          controller: _effectScaleText,
          suffix: 'x',
          min: 0.25,
          max: 3,
          skillsSetOwn: _library.skillsSetEffectDisplayScale,
          ownNote:
              'Each skill uses its own effect artwork scale (Appearance). This value is not used.',
          globalNote:
              'Every effect is drawn at this size. The effect artwork scale in each skill is disabled.',
          onValue: (v) => _library = _library.withGlobal(effectDisplayScale: v),
          onSkillsSetOwn: (v) =>
              _library = _library.withGlobal(skillsSetEffectDisplayScale: v),
          applyKey: const ValueKey('apply-all-effect-display-scale'),
          shown: (v) => '${_formatSeconds(v)}x',
          applyToAll: (library, v) =>
              library.applyToAll(_tuning, effectDisplayScale: v),
        ),
      ],
    );
  }

  Widget _builtInSkills() => DefaultTabController(
    length: 4,
    // Opens on Weapons; Global sits first, one tap away.
    initialIndex: 1,
    child: Column(
      children: [
        const TabBar(
          key: ValueKey('built-in-skill-tabs'),
          tabs: [
            Tab(text: 'Global'),
            Tab(text: 'Weapons'),
            Tab(text: 'Power-ups'),
            Tab(text: 'Traps'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _globalSettings(),
              _list(false, category: 'Weapons'),
              _list(false, category: 'Power-ups'),
              _list(
                false,
                category: 'Traps',
                headers: [
                  for (final trapName in _arenaTrapFields.keys)
                    if (_query.trim().isEmpty ||
                        trapName.toLowerCase().contains(
                          _query.trim().toLowerCase(),
                        ) ||
                        'arena'.contains(_query.trim().toLowerCase()))
                      _arenaTrapCard(trapName),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Skill Management'),
          actions: [
            if (AppSettingsScope.maybeScope(context)?.sprites
                case final repository?)
              IconButton(
                key: const ValueKey('manage-sprites'),
                tooltip: 'Sprites',
                icon: const Icon(Icons.photo_library_outlined),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SpritesScreen(
                        repository: repository,
                        library: _library,
                        tuning: _tuning,
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            IconButton(
              key: const ValueKey('import-skill-library'),
              tooltip: 'Import versioned JSON',
              onPressed: _importLibrary,
              icon: const Icon(Icons.file_upload_outlined),
            ),
            IconButton(
              key: const ValueKey('export-skill-library'),
              tooltip: 'Export versioned JSON',
              onPressed: _exportLibrary,
              icon: const Icon(Icons.file_download_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Built-in'),
              Tab(text: 'Custom'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search skills',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          key: const ValueKey('clear-skill-search'),
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'Built-in edits affect gameplay immediately. Custom skills keep their own identity and may share a visual template without replacing one another.',
                style: AppText.ui(
                  12,
                  FontWeight.w500,
                  color: c.muted,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(children: [_builtInSkills(), _list(true)]),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('create-new-skill'),
                  tooltip: 'Create a completely new skill',
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _library = SkillLibrary.defaults;
                      _effectVisuals = EffectRenderMode.sprite;
                    }),
                    child: const Text('Restore defaults'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      SkillManagementResult(
                        library: _library,
                        tuning: _tuning,
                        effectVisuals: _effectVisuals,
                      ),
                    ),
                    child: const Text('Save Library'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillEditor extends StatefulWidget {
  const _SkillEditor({
    required this.skill,
    required this.rarity,
    this.library = SkillLibrary.defaults,
    this.tuning = PowerUpConfig.defaults,
    this.onSave,
  });
  final SkillDefinition skill;

  /// The library the skill belongs to: the skills it can fire, and checks on that reference.
  final SkillLibrary library;
  final PowerUpConfig tuning;
  final PowerUpRarity? rarity;
  final Future<void> Function(_SkillEditResult)? onSave;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  bool _saving = false;
  final _saveMessages = GlobalKey<ScaffoldMessengerState>();

  Future<void> _saveEditedSkill() async {
    final result = _result;
    if (_saving ||
        result == null ||
        result.compatibilityIssues.isNotEmpty ||
        _payloadProblem(result) != null) {
      return;
    }
    final edited = _SkillEditResult(result, _rarity);
    if (widget.onSave == null) {
      Navigator.pop(context, edited);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.onSave!(edited);
      if (mounted) {
        _saveMessages.currentState!
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Skill saved.')));
      }
    } catch (error) {
      if (mounted) {
        _saveMessages.currentState!
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Skill could not be saved: $error')),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  late final _name = TextEditingController(text: widget.skill.name);

  /// Combine: the weapon it looks like (null: its own) and the skill it fires (null: its own projectile).
  late PowerUpKind? _artwork = widget.skill.artworkKind;
  late String? _payload = widget.skill.payloadSkillId;

  /// What's wrong with the fired-skill choice, checked against the library with this edit in it.
  String? _payloadProblem(SkillDefinition skill) => widget.library
      .withDefinition(skill, widget.tuning)
      .payloadProblem(skill.validated(), widget.tuning);
  late final Map<String, TextEditingController> _numbers = {
    if (widget.skill.isComposed || widget.skill.arsenalDamage != null)
      'arsenal': TextEditingController(
        text: '${widget.skill.arsenalDamage ?? 0}',
      ),
    if (widget.skill.isComposed || widget.skill.allOutDamage != null)
      'allOut': TextEditingController(
        text: '${widget.skill.allOutDamage ?? 0}',
      ),
    if (widget.skill.isComposed)
      'dotArsenal': TextEditingController(
        text:
            '${widget.skill.dotArsenalDamage ?? widget.skill.arsenalDamage ?? 0}',
      ),
    if (widget.skill.isComposed)
      'dotAllOut': TextEditingController(
        text:
            '${widget.skill.dotAllOutDamage ?? widget.skill.allOutDamage ?? 0}',
      ),
    if (widget.skill.isComposed || widget.skill.durationSeconds != null)
      'duration': TextEditingController(
        text: '${widget.skill.durationSeconds ?? 2}',
      ),
    if (widget.skill.isComposed || widget.skill.projectileCount != null)
      'count': TextEditingController(
        text: '${widget.skill.projectileCount ?? 1}',
      ),
    if (widget.skill.isComposed || widget.skill.projectileSpeed != null)
      'speed': TextEditingController(
        text: '${widget.skill.projectileSpeed ?? 1.4}',
      ),
    if (widget.skill.isComposed || widget.skill.spreadDegrees != null)
      'spread': TextEditingController(
        text: '${widget.skill.spreadDegrees ?? 0}',
      ),
    if (widget.skill.isComposed || widget.skill.maxBounces != null)
      'bounces': TextEditingController(text: '${widget.skill.maxBounces ?? 0}'),
    'range': TextEditingController(text: '${widget.skill.range}'),
    'projectileSize': TextEditingController(
      text: '${widget.skill.projectileSize}',
    ),
    'projectileSpin': TextEditingController(
      text: '${widget.skill.projectileSpin}',
    ),
    'weaponDisplayScale': TextEditingController(
      text: '${widget.skill.weaponDisplayScale}',
    ),
    'pickupDisplayScale': TextEditingController(
      text: '${widget.skill.pickupDisplayScale}',
    ),
    'effectDisplayScale': TextEditingController(
      text: '${widget.skill.effectDisplayScale}',
    ),
    'weaponGripInset': TextEditingController(
      text: '${widget.skill.weaponGripInset}',
    ),
    'weaponGripSide': TextEditingController(
      text: '${widget.skill.weaponGripSide}',
    ),
    'weaponGripRotation': TextEditingController(
      text: '${widget.skill.weaponGripRotation}',
    ),
    'effectStrength': TextEditingController(
      text: '${widget.skill.effectStrength}',
    ),
    'healing': TextEditingController(text: '${widget.skill.healing}'),
    'shieldHits': TextEditingController(text: '${widget.skill.shieldHits}'),
    'frozenDamageMultiplier': TextEditingController(
      text: '${widget.skill.frozenDamageMultiplier}',
    ),
    'frozenCollisionDamage': TextEditingController(
      text: '${widget.skill.frozenCollisionDamage}',
    ),
    if (widget.skill.isComposed)
      'repeatCount': TextEditingController(text: '${widget.skill.repeatCount}'),
    if (widget.skill.isComposed)
      'repeatInterval': TextEditingController(
        text: '${widget.skill.repeatIntervalSeconds}',
      ),
    if (widget.skill.isComposed)
      'startDelay': TextEditingController(
        text: '${widget.skill.startDelaySeconds}',
      ),
    if (widget.skill.isComposed)
      'tickInterval': TextEditingController(
        text: '${widget.skill.tickIntervalSeconds}',
      ),
    if (widget.skill.isComposed)
      'cooldown': TextEditingController(
        text: '${widget.skill.cooldownSeconds}',
      ),
    if (widget.skill.isComposed)
      'screenShake': TextEditingController(text: '${widget.skill.screenShake}'),
    if (widget.skill.isComposed)
      'triggerInterval': TextEditingController(
        text: '${widget.skill.triggerIntervalSeconds}',
      ),
    'knockback': TextEditingController(text: '${widget.skill.knockback}'),
    'meleeReach': TextEditingController(text: '${widget.skill.meleeReach}'),
    'bubbleDuration': TextEditingController(
      text: '${widget.skill.bubbleDurationSeconds}',
    ),
    'handEffectScale': TextEditingController(
      text: '${widget.skill.handEffectScale}',
    ),
    'handEffectDuration': TextEditingController(
      text: '${widget.skill.handEffectDurationSeconds}',
    ),
    'castingDuration': TextEditingController(
      text: '${widget.skill.castingDurationSeconds}',
    ),
    'castingScale': TextEditingController(text: '${widget.skill.castingScale}'),
    'shellSize': TextEditingController(text: '${widget.skill.shellSize}'),
    'shellCount': TextEditingController(text: '${widget.skill.shellCount}'),
  };

  /// Shell settings (gun skills): Default (null) / On / Off, the sprite id (null: brass) and rest.
  late bool? _shellEnabled = widget.skill.shellEnabled;
  late String? _iconSpriteId = widget.skill.iconSpriteId;
  late String? _projectileSpriteId = widget.skill.projectileSpriteId;
  late String? _impactSpriteId = widget.skill.impactSpriteId;
  late String? _castingSpriteId = widget.skill.castingSpriteId;
  late bool _castingFollowsActive = widget.skill.castingFollowsActive;
  late SkillHeldFacing _heldFacing = widget.skill.heldFacing;
  late String? _shellSprite = widget.skill.shellSprite;
  late bool _shellRandomRest = widget.skill.shellRandomRest;
  late SkillVisualMode _sprite = widget.skill.spriteMode;
  late SkillVisualMode _effect = widget.skill.effectMode;
  late bool _globalEffectVisuals = widget.skill.useGlobalEffectVisuals;
  late bool _enabled = widget.skill.enabled;
  late bool _homing = widget.skill.homing;
  late bool _returnsToOrigin = widget.skill.returnsToOrigin;
  late bool _trackNearestOpponent = widget.skill.trackNearestOpponent;
  late SkillTrigger? _trigger = widget.skill.trigger;
  late SkillTargeting? _targeting = widget.skill.targeting;
  late SkillDelivery? _delivery = widget.skill.delivery;
  late SkillEffectType? _effectType = widget.skill.effectType;
  late SkillEffectType? _secondaryEffectType = widget.skill.secondaryEffectType;
  late SkillCalloutStyle _calloutStyle = widget.skill.calloutStyle;
  late SkillBubbleType _bubbleType = widget.skill.bubbleType;
  late SkillHandedness _handedness = widget.skill.handedness;
  late SkillCategory _category = widget.skill.resolvedCategory;
  late bool _explodesOnImpact = widget.skill.explodesOnImpact;
  late PowerUpRarity? _rarity = widget.rarity;
  late final _effectColor = TextEditingController(
    text: (widget.skill.effectColor & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase(),
  );
  late final _yell = TextEditingController(text: widget.skill.yell);
  late bool _descriptionOverride = widget.skill.description.isNotEmpty;
  late String _generatedDescription = powerUpDescription(
    widget.skill.baseKind,
    arsenal: true,
    config: widget.library.applyTo(widget.tuning),
  );
  late final _description = TextEditingController(
    text: widget.skill.description.isEmpty && !widget.skill.custom
        ? _generatedDescription
        : widget.skill.description,
  );
  late final _sound = TextEditingController(text: widget.skill.soundCue);
  late int _handColor = widget.skill.handEffectColor;
  late int _spriteTint = widget.skill.spriteTint;
  int _resetGeneration = 0;

  @override
  void dispose() {
    _name.dispose();
    _sound.dispose();
    _yell.dispose();
    _description.dispose();
    _effectColor.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _double(String key) => double.tryParse(_numbers[key]?.text ?? '');
  int? _int(String key) {
    final value = _double(key);
    return value != null && value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : null;
  }

  bool _usesEffect(SkillEffectType effect) =>
      _effectType == effect || _secondaryEffectType == effect;

  bool get _showsHealing =>
      _usesEffect(SkillEffectType.heal) ||
      (!widget.skill.isComposed && widget.skill.baseKind == PowerUpKind.apple);

  bool get _showsShieldHits =>
      _usesEffect(SkillEffectType.shield) ||
      (!widget.skill.isComposed &&
          widget.skill.baseKind == PowerUpKind.goldenArmor);

  bool get _showsFreezeSettings =>
      _usesEffect(SkillEffectType.freeze) ||
      (!widget.skill.isComposed && widget.skill.baseKind == PowerUpKind.freeze);

  /// Strikes on a bump (and so can have a melee reach): a collision trigger, a blade, the orbiting
  /// flail or a shield, matching the match's contact rules.
  bool get _strikesOnContact =>
      (_trigger == SkillTrigger.collision &&
          _targeting != null &&
          _delivery != null &&
          _effectType != null) ||
      widget.skill.baseKind.isBlade ||
      widget.skill.baseKind == PowerUpKind.orbitingFlail ||
      widget.skill.baseKind == PowerUpKind.shield;

  bool get _usesProjectileDelivery =>
      _delivery == SkillDelivery.projectile ||
      (!widget.skill.isComposed &&
          widget.skill.baseKind.isGun &&
          !const [
            PowerUpKind.fireWall,
            PowerUpKind.energyWave,
            PowerUpKind.flamethrower,
            PowerUpKind.sniperRifle,
            PowerUpKind.busterSword,
          ].contains(widget.skill.baseKind));

  /// The Shell group shows for skills that shoot: a gun carrier, or a custom skill that fires
  /// projectiles after an aim (the only custom path that ejects casings).
  bool get _showsShellSettings => _editsComposed
      ? _delivery == SkillDelivery.projectile &&
            _trigger == SkillTrigger.aimedFire
      : widget.skill.baseKind.isGun;

  /// Whether the edited values make a composed skill (trigger, targeting, delivery and effect set).
  bool get _editsComposed =>
      _trigger != null &&
      _targeting != null &&
      _delivery != null &&
      _effectType != null;

  /// What "Default" means for Drops shells here (a composed or combined skill drops none).
  /// Read from [SkillDefinition.defaultDropsShells] on the edited values, the same rule the match uses.
  bool get _shellDefault => SkillDefinition(
    id: widget.skill.id,
    name: widget.skill.name,
    baseKind: widget.skill.baseKind,
    trigger: _trigger,
    targeting: _targeting,
    delivery: _delivery,
    effectType: _effectType,
    payloadSkillId: _payload,
  ).defaultDropsShells;

  /// "Brass shell (default)" (null) plus the bundled projectile, effect and animation sprites and
  /// any uploaded ones, and the current choice even if it is no longer loaded.
  List<String?> get _shellSpriteChoices {
    final ids =
        SpriteRegistry.ids
            .where(
              (id) =>
                  id.startsWith('projectile.') ||
                  id.startsWith('effect.') ||
                  id.startsWith('anim.') ||
                  id.startsWith('custom.'),
            )
            .toList()
          ..sort();
    return [
      null,
      if (_shellSprite != null && !ids.contains(_shellSprite)) _shellSprite,
      ...ids,
    ];
  }

  static String _shellSpriteLabel(String? id) {
    if (id == null) return 'Brass shell (default)';
    if (!SpriteRegistry.has(id)) return '$id (not loaded, brass shell)';
    if (id.startsWith('custom.')) return SpriteRegistry.displayLabel(id);
    final dot = id.indexOf('.');
    final group = switch (id.substring(0, dot)) {
      'projectile' => 'Projectile',
      'effect' => 'Effect',
      'anim' => 'Animation',
      'custom' => 'Uploaded',
      final other => other,
    };
    final name = id.substring(dot + 1).replaceAll(RegExp(r'[._-]+'), ' ');
    return '$group: $name';
  }

  bool get _canSteerProjectile =>
      _usesProjectileDelivery &&
      (widget.skill.isComposed ||
          !const [
            PowerUpKind.grenade,
            PowerUpKind.molotov,
          ].contains(widget.skill.baseKind));

  int? get _colorValue {
    final value = _effectColor.text.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return 0xFF000000 | int.parse(value, radix: 16);
  }

  void _restoreDefaults() {
    final defaults = widget.skill.custom
        ? (widget.skill.isComposed
              ? SkillLibrary.defaults.create(
                  widget.skill.name,
                  widget.skill.baseKind,
                )
              : SkillLibrary.defaults
                    .builtIn(widget.skill.baseKind, PowerUpConfig.defaults)
                    .copyWith(
                      id: widget.skill.id,
                      name: widget.skill.name,
                      custom: true,
                      enabled: false,
                    ))
        : SkillLibrary.defaults.builtIn(
            widget.skill.baseKind,
            PowerUpConfig.defaults,
          );
    void number(String key, num? value) {
      final controller = _numbers[key];
      if (value != null && controller != null) {
        controller.text = '$value';
      }
    }

    setState(() {
      _resetGeneration++;
      _handColor = defaults.handEffectColor;
      _spriteTint = defaults.spriteTint;
      _rarity = PowerUpConfig.defaults.rarityOf(widget.skill.baseKind);
      _name.text = defaults.name;
      // A built-in's description goes back to the generated text; a custom skill keeps its own.
      if (!widget.skill.custom) {
        _descriptionOverride = false;
        _generatedDescription = powerUpDescription(
          widget.skill.baseKind,
          arsenal: true,
          config: PowerUpConfig.defaults,
        );
        _description.text = _generatedDescription;
      }
      _enabled = defaults.enabled;
      _homing = defaults.homing;
      _returnsToOrigin = defaults.returnsToOrigin;
      _trackNearestOpponent = defaults.trackNearestOpponent;
      _sprite = defaults.spriteMode;
      _effect = defaults.effectMode;
      _globalEffectVisuals = defaults.useGlobalEffectVisuals;
      _trigger = defaults.trigger;
      _targeting = defaults.targeting;
      _delivery = defaults.delivery;
      _effectType = defaults.effectType;
      _secondaryEffectType = defaults.secondaryEffectType;
      _calloutStyle = defaults.calloutStyle;
      _bubbleType = defaults.bubbleType;
      _handedness = defaults.handedness;
      _category = defaults.resolvedCategory;
      _explodesOnImpact = defaults.explodesOnImpact;
      _effectColor.text = (defaults.effectColor & 0xFFFFFF)
          .toRadixString(16)
          .padLeft(6, '0')
          .toUpperCase();
      _sound.text = defaults.soundCue;
      _yell.text = defaults.yell;
      number('arsenal', defaults.arsenalDamage);
      number('allOut', defaults.allOutDamage);
      number('dotArsenal', defaults.dotArsenalDamage);
      number('dotAllOut', defaults.dotAllOutDamage);
      number('duration', defaults.durationSeconds);
      number('count', defaults.projectileCount);
      number('speed', defaults.projectileSpeed);
      number('spread', defaults.spreadDegrees);
      number('bounces', defaults.maxBounces);
      number('range', defaults.range);
      number('projectileSize', defaults.projectileSize);
      number('projectileSpin', defaults.projectileSpin);
      number('weaponDisplayScale', defaults.weaponDisplayScale);
      number('pickupDisplayScale', defaults.pickupDisplayScale);
      number('effectDisplayScale', defaults.effectDisplayScale);
      number('weaponGripInset', defaults.weaponGripInset);
      number('weaponGripSide', defaults.weaponGripSide);
      number('weaponGripRotation', defaults.weaponGripRotation);
      number('effectStrength', defaults.effectStrength);
      number('healing', defaults.healing);
      number('shieldHits', defaults.shieldHits);
      number('frozenDamageMultiplier', defaults.frozenDamageMultiplier);
      number('frozenCollisionDamage', defaults.frozenCollisionDamage);
      number('knockback', defaults.knockback);
      number('meleeReach', defaults.meleeReach);
      number('repeatCount', defaults.repeatCount);
      number('repeatInterval', defaults.repeatIntervalSeconds);
      number('startDelay', defaults.startDelaySeconds);
      number('tickInterval', defaults.tickIntervalSeconds);
      number('cooldown', defaults.cooldownSeconds);
      number('screenShake', defaults.screenShake);
      number('triggerInterval', defaults.triggerIntervalSeconds);
      number('bubbleDuration', defaults.bubbleDurationSeconds);
      number('handEffectScale', defaults.handEffectScale);
      number('handEffectDuration', defaults.handEffectDurationSeconds);
      number('shellSize', defaults.shellSize);
      number('shellCount', defaults.shellCount);
      _shellEnabled = defaults.shellEnabled;
      _iconSpriteId = defaults.iconSpriteId;
      _projectileSpriteId = defaults.projectileSpriteId;
      _impactSpriteId = defaults.impactSpriteId;
      _castingSpriteId = defaults.castingSpriteId;
      _heldFacing = defaults.heldFacing;
      _castingFollowsActive = defaults.castingFollowsActive;
      number('castingDuration', defaults.castingDurationSeconds);
      number('castingScale', defaults.castingScale);
      _shellSprite = defaults.shellSprite;
      _shellRandomRest = defaults.shellRandomRest;
    });
  }

  Future<void> _previewFinisher() async {
    final skill = _result;
    if (skill == null) return;
    const winner = CustomBall(
      id: 'skill-preview-a',
      name: 'Ball A',
      primaryColor: Color(0xFFFF5B4D),
      glowColor: Color(0xFFFFA38F),
    );
    const loser = CustomBall(
      id: 'skill-preview-b',
      name: 'Ball B',
      primaryColor: Color(0xFF4D9DFF),
      glowColor: Color(0xFF7EDBFF),
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (previewContext) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: HarpoonCinematic(
                    winner: winner,
                    loser: loser,
                    move: skill.name,
                    skill: skill,
                    skillLibrary: widget.library,
                    visualMove: skill.displayKind.label,
                    artworkTint: skill.spriteTint,
                    effectSprites: skill.usesSpriteEffects(
                      globalSprite:
                          AppSettingsScope.of(context).explosionRenderMode ==
                          EffectRenderMode.sprite,
                    ),
                    onHookFired: () =>
                        GameAudio.instance.skillCue(skill.soundCue),
                    onImpact: GameAudio.instance.hit,
                    onFinished: () => Navigator.of(previewContext).maybePop(),
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
    );
  }

  Future<void> _previewSkill() async {
    final skill = _result;
    if (skill == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SkillPreviewDialog(skill: skill),
    );
  }

  Future<void> _demoSkill() async {
    final skill = _result;
    if (skill == null) return;
    final effectMode = AppSettingsScope.of(context).explosionRenderMode;
    final library = widget.library;
    final tuning = widget.tuning;
    await showDialog<void>(
      context: context,
      builder: (_) => SkillDemoDialog(
        skill: skill,
        library: library,
        tuning: tuning,
        effectMode: effectMode,
      ),
    );
  }

  Future<void> _testInLiveArena() async {
    final skill = _result;
    if (skill == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PowerUpTestScreen(initialSkill: skill)),
    );
  }

  void _showInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Skill settings guide'),
      content: const SingleChildScrollView(
        child: Text(
          'ACTIVE IN MATCHES makes this independent custom skill available alongside the built-in skills.\n\n'
          'VISUAL TEMPLATE supplies existing artwork and starting defaults. Custom skills keep their own settings.\n\n'
          'TRIGGER decides when the behavior runs: on pickup, after aiming and firing, on collision, on a repeating match timer, after its owner takes damage, or after its owner eliminates an opponent. Timer and reactive triggers are innate while the custom skill is active; they do not require collecting the carrier.\n\n'
          'TARGETING chooses the owner, nearest opponent, every opponent, the opponent in the ball\'s travel direction, or the opponent nearest a projected arena location.\n\n'
          'DELIVERY supports immediate, projectile, area, beam, aura, orbit, and boundary-hazard behavior.\n\n'
          'EFFECT decides what happens: damage, DoT, healing, shielding, freezing, stunning, speed, pulling, knockback, teleporting, equipping the carrier weapon, or disarming. The editor only shows parameters used by the selected effect and delivery. Weapons hide healing unless Healing effect is intentionally enabled. Damage fields apply to Arsenal life and All-Out lines. Duration controls timed effects; projectile count controls shield hits.\n\n'
          'SECONDARY EFFECT runs immediately after the primary effect. START DELAY postpones the first activation. REPEAT COUNT includes the first activation; the interval controls the pause between later activations. DoT uses its own TICK INTERVAL. COOLDOWN prevents the same ball from activating the skill again too soon.\n\n'
          'EFFECT COLOR tints generated impact particles. SCREEN SHAKE controls impact camera movement from none (0) to maximum (1). HANDEDNESS can preserve the carrier default or explicitly make a weapon one-handed or two-handed. GRIP INSET moves the held artwork inward by a fraction of the ball radius so its handle sits in the hand. TRACK NEAREST OPPONENT turns an equipped weapon artwork toward its nearest target.\n\n'
          'ITEM and IMPACT visuals choose pixel-art sprites or vector rendering. Their previews update immediately.\n\n'
          'SOUND plays when the skill activates. Use the Play button to preview it. YELL is the comic callout shown by the ball. BUBBLE SHAPE offers Shout for attacks, Speech for recovery, Thought for quiet or psychic skills, and Radio for tech or command skills.',
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

  SkillDefinition? get _result {
    if (_name.text.trim().isEmpty ||
        _numbers.keys.any((key) => _numberError(key) != null) ||
        (widget.skill.isComposed && _colorValue == null)) {
      return null;
    }
    return widget.skill.copyWith(
      name: _name.text.trim(),
      description: widget.skill.custom || _descriptionOverride
          ? SkillDefinition.cleanDescription(_description.text)
          : '',
      enabled: _enabled,
      category: _category,
      arsenalDamage: _double('arsenal'),
      allOutDamage: _int('allOut'),
      dotArsenalDamage: _double('dotArsenal'),
      dotAllOutDamage: _int('dotAllOut'),
      durationSeconds: _double('duration'),
      projectileCount: _int('count'),
      projectileSpeed: _double('speed'),
      spreadDegrees: _double('spread'),
      maxBounces: _int('bounces'),
      range: _double('range'),
      projectileSize: _double('projectileSize'),
      projectileSpin: _double('projectileSpin'),
      homing: _homing,
      returnsToOrigin: _returnsToOrigin,
      trackNearestOpponent: _trackNearestOpponent,
      weaponDisplayScale: _double('weaponDisplayScale'),
      pickupDisplayScale: _double('pickupDisplayScale'),
      effectDisplayScale: _double('effectDisplayScale'),
      weaponGripInset: _double('weaponGripInset'),
      weaponGripSide: _double('weaponGripSide'),
      weaponGripRotation: _double('weaponGripRotation'),
      heldFacing: _heldFacing,
      effectStrength: _double('effectStrength'),
      healing: _double('healing'),
      shieldHits: _int('shieldHits'),
      frozenDamageMultiplier: _double('frozenDamageMultiplier'),
      frozenCollisionDamage: _double('frozenCollisionDamage'),
      knockback: _double('knockback'),
      meleeReach: _double('meleeReach'),
      spriteMode: _sprite,
      effectMode: _effect,
      useGlobalEffectVisuals: _globalEffectVisuals,
      soundCue: _sound.text.trim().isEmpty ? 'default' : _sound.text.trim(),
      trigger: _trigger,
      targeting: _targeting,
      delivery: _delivery,
      effectType: _effectType,
      secondaryEffectType: _secondaryEffectType,
      repeatCount: _int('repeatCount'),
      repeatIntervalSeconds: _double('repeatInterval'),
      startDelaySeconds: _double('startDelay'),
      tickIntervalSeconds: _double('tickInterval'),
      cooldownSeconds: _double('cooldown'),
      triggerIntervalSeconds: _double('triggerInterval'),
      yell: _yell.text,
      calloutStyle: _calloutStyle,
      bubbleType: _bubbleType,
      bubbleDurationSeconds: _double('bubbleDuration'),
      handEffectScale: _double('handEffectScale'),
      handEffectColor: _handColor,
      handEffectDurationSeconds: _double('handEffectDuration'),
      explodesOnImpact: _explodesOnImpact,
      effectColor: _colorValue,
      spriteTint: _spriteTint,
      screenShake: _double('screenShake'),
      handedness: _handedness,
      artworkKind: _artwork,
      payloadSkillId: _payload,
      shellEnabled: _shellEnabled,
      iconSpriteId: _iconSpriteId,
      projectileSpriteId: _projectileSpriteId,
      impactSpriteId: _impactSpriteId,
      castingSpriteId: _castingSpriteId,
      castingDurationSeconds: _double('castingDuration'),
      castingScale: _double('castingScale'),
      castingFollowsActive: _castingFollowsActive,
      shellSprite: _shellSprite,
      shellSize: _double('shellSize'),
      shellCount: _int('shellCount'),
      shellRandomRest: _shellRandomRest,
    );
  }

  static const _limits = <String, (double, double)>{
    'weaponDisplayScale': (0.25, 3),
    'pickupDisplayScale': (0.25, 3),
    'effectDisplayScale': (0.25, 3),
    'weaponGripInset': (-1.5, 1.5),
    'weaponGripSide': (-1.5, 1.5),
    'weaponGripRotation': (-180, 180),
    'projectileSize': (0.1, 5),
    'screenShake': (0, 1),
    'knockback': (0, 100),
    'meleeReach': (0, 3),
    'range': (0.05, 12),
    'arsenal': (0, 500),
    'allOut': (0, 360),
    'dotArsenal': (0, 500),
    'dotAllOut': (0, 360),
    'duration': (0.1, 60),
    'count': (1, 100),
    'speed': (0.1, 10),
    'spread': (0, 360),
    'bounces': (0, 20),
    'projectileSpin': (-2160, 2160),
    'effectStrength': (0, 10),
    'healing': (0, 500),
    'shieldHits': (0, 20),
    'frozenDamageMultiplier': (1, 5),
    'frozenCollisionDamage': (0, 200),
    'bubbleDuration': (0.25, 10),
    'repeatCount': (1, 10),
    'repeatInterval': (0.1, 10),
    'startDelay': (0, 30),
    'tickInterval': (0.1, 10),
    'cooldown': (0, 60),
    'triggerInterval': (0.5, 120),
    'handEffectScale': (0.1, 4),
    'handEffectDuration': (0.1, 10),
    'castingDuration': (0.1, 10),
    'castingScale': (0.25, 4),
    'shellSize': (0.25, 10),
    'shellCount': (1, 20),
  };

  /// Number fields that may go below zero.
  static const _signedKeys = {
    'projectileSpin',
    'weaponGripInset',
    'weaponGripSide',
    'weaponGripRotation',
  };

  static const _wholeNumberKeys = {
    'shellCount',
    'count',
    'allOut',
    'dotAllOut',
    'bounces',
    'repeatCount',
    'shieldHits',
  };

  void _stepWholeNumber(String key, int delta) {
    final value = int.tryParse(_numbers[key]!.text);
    if (value == null) return;
    final limits = _limits[key]!;
    setState(
      () => _numbers[key]!.text = (value + delta)
          .clamp(limits.$1.toInt(), limits.$2.toInt())
          .toString(),
    );
  }

  Future<void> _previewGrip() async {
    final result = await GripPreviewDialog.show(
      context,
      kind: widget.skill.baseKind,
      artwork: _artwork ?? widget.skill.baseKind,
      spriteId: _iconSpriteId,
      tint: _spriteTint,
      useSprite: _sprite == SkillVisualMode.sprite,
      displayScale: _double('weaponDisplayScale') ?? 1,
      grip: GripValues(
        inset: _double('weaponGripInset') ?? 0,
        side: _double('weaponGripSide') ?? 0,
        rotation: _double('weaponGripRotation') ?? 0,
        facing: _heldFacing,
      ),
    );
    if (result == null || !mounted) return;
    // Whole numbers without decimals ("20", not "20.00"); radii keep two.
    String text(double v) {
      final rounded = double.parse(v.toStringAsFixed(2));
      return rounded == rounded.roundToDouble()
          ? '${rounded.round()}'
          : rounded.toStringAsFixed(2);
    }

    setState(() {
      _numbers['weaponGripInset']!.text = text(result.inset);
      _numbers['weaponGripSide']!.text = text(result.side);
      _numbers['weaponGripRotation']!.text = '${result.rotation.round()}';
      _heldFacing = result.facing;
    });
  }

  String? _numberError(String key) {
    final raw = _numbers[key]?.text ?? '';
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) return 'Enter a number';
    if (value < 0 && !_signedKeys.contains(key)) return 'Must be zero or more';
    if (_wholeNumberKeys.contains(key) && value != value.roundToDouble()) {
      return 'Use a whole number';
    }
    final limits = _limits[key];
    if (limits != null && (value < limits.$1 || value > limits.$2)) {
      return '${limits.$1} to ${limits.$2}';
    }
    return null;
  }

  /// Combine: look like any weapon, and fire any projectile skill (built-in or custom) as its shots.
  List<Widget> _combineSection(SkillDefinition? result) {
    final current = result ?? widget.skill;
    final candidates = widget.library.payloadCandidates(current, widget.tuning);
    final problem = result == null ? null : _payloadProblem(result);
    final known = candidates.any((c) => c.id == _payload);
    Widget option(PowerUpKind kind, String label) => Row(
      children: [
        PowerUpIcon(kind, size: 24),
        const SizedBox(width: 10),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    return [
      _section(
        'Combine',
        'Look like another weapon, and fire any projectile skill as this skill\'s shots.',
      ),
      _fixedRow(
        'Looks like',
        DropdownButtonFormField<PowerUpKind?>(
          isExpanded: true,
          key: const ValueKey('skill-looks-like'),
          initialValue: _artwork,
          items: [
            DropdownMenuItem<PowerUpKind?>(
              value: null,
              child: option(
                widget.skill.baseKind,
                'Own look (${widget.skill.baseKind.label})',
              ),
            ),
            for (final kind in PowerUpKind.values.where((k) => k.isWeapon))
              DropdownMenuItem<PowerUpKind?>(
                value: kind,
                child: option(kind, kind.label),
              ),
          ],
          onChanged: (value) => setState(() => _artwork = value),
        ),
      ),
      _fixedRow(
        'Fires',
        DropdownButtonFormField<String?>(
          isExpanded: true,
          key: const ValueKey('skill-fires'),
          initialValue: _payload,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: option(widget.skill.baseKind, 'Own projectile'),
            ),
            for (final candidate in candidates)
              DropdownMenuItem<String?>(
                value: candidate.id,
                child: option(
                  candidate.baseKind,
                  candidate.custom
                      ? candidate.name
                      : '${candidate.name} (built-in)',
                ),
              ),
            if (_payload != null && !known)
              DropdownMenuItem<String?>(
                value: _payload,
                child: Text(
                  'Missing: $_payload',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _payload = value),
        ),
      ),
      if (_payload != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Number of shots and spread come from this skill (Damage & Timing). Damage, flight, return, '
            'explosion, knockback, size, tint and sound come from the skill it fires.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      if (problem != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            problem,
            key: const ValueKey('skill-fires-problem'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ];
  }

  /// Appearance > Shell: whether firing drops casings, their sprite (with a preview), size and rest.
  List<Widget> _shellGroup() {
    final choices = _shellSpriteChoices;
    return [
      _section(
        'Shell',
        'Spent casings this gun drops to the arena floor. They only change the look, never the match.',
      ),
      _fixedRow(
        'Drops shells',
        DropdownButtonFormField<String>(
          key: const ValueKey('skill-shell-enabled'),
          isExpanded: true,
          initialValue: switch (_shellEnabled) {
            null => 'default',
            true => 'on',
            false => 'off',
          },
          decoration: const InputDecoration(),
          items: [
            DropdownMenuItem(
              value: 'default',
              child: Text('Default (${_shellDefault ? 'On' : 'Off'})'),
            ),
            const DropdownMenuItem(value: 'on', child: Text('On')),
            const DropdownMenuItem(value: 'off', child: Text('Off')),
          ],
          onChanged: (value) => setState(
            () => _shellEnabled = switch (value) {
              'on' => true,
              'off' => false,
              _ => null,
            },
          ),
        ),
      ),
      _fixedRow(
        'Shell sprite',
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String?>(
                key: const ValueKey('skill-shell-sprite'),
                isExpanded: true,
                initialValue: _shellSprite,
                decoration: const InputDecoration(),
                items: [
                  for (final id in choices)
                    DropdownMenuItem(
                      value: id,
                      child: Text(
                        _shellSpriteLabel(id),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _shellSprite = value),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              key: const ValueKey('skill-shell-preview'),
              dimension: 40,
              child: CustomPaint(
                painter: _ShellPreviewPainter(
                  spriteId: _shellSprite,
                  size: (_double('shellSize') ?? 1).clamp(0.25, 10),
                ),
              ),
            ),
          ],
        ),
      ),
      _number('shellSize', 'Shell size', suffix: 'x'),
      _number('shellCount', 'Shells per shot / volley'),
      const Text(
        'One ejection per shot, or per volley for Shotgun and Bow. Gatling ejects on each round.',
      ),
      SwitchListTile(
        key: const ValueKey('skill-shell-random-rest'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Random rest orientation'),
        subtitle: const Text(
          'Landed shells lie at varied angles. Off: they keep the angle they hit the floor at.',
        ),
        value: _shellRandomRest,
        onChanged: (value) => setState(() => _shellRandomRest = value),
      ),
    ];
  }

  Widget _fixedRow(String label, Widget control) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Expanded(flex: 6, child: control),
      ],
    ),
  );

  Widget _section(String title, String description) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _visualOption(SkillVisualMode mode) => Row(
    children: [
      SizedBox(
        width: 28,
        height: 28,
        child: mode == SkillVisualMode.sprite
            ? PowerUpIcon(widget.skill.baseKind, size: 24, tint: _spriteTint)
            : SkillArtworkTint.widget(
                _spriteTint,
                CustomPaint(
                  painter: _VectorSkillPreview(widget.skill.baseKind),
                ),
              ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(mode == SkillVisualMode.sprite ? 'Sprite' : 'Vector'),
      ),
    ],
  );

  Widget _number(
    String key,
    String label, {
    String? suffix,
    bool enabled = true,
    String? disabledNote,
    String? helper,
  }) {
    final wholeNumber = _wholeNumberKeys.contains(key);
    final limits = _limits[key];
    final value = _double(key);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            _fixedRow(
              wholeNumber && suffix != null ? '$label ($suffix)' : label,
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _numbers[key]!,
                builder: (context, editingValue, _) {
                  final value = double.tryParse(editingValue.text);
                  return TextField(
                    key: ValueKey('skill-field-$key'),
                    enabled: enabled,
                    controller: _numbers[key],
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: !wholeNumber,
                      signed: _signedKeys.contains(key),
                    ),
                    inputFormatters: wholeNumber
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    decoration: InputDecoration(
                      suffixText: wholeNumber ? null : suffix,
                      contentPadding: wholeNumber
                          ? const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 12,
                            )
                          : null,
                      prefixIconConstraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      suffixIconConstraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 44,
                      ),
                      prefixIcon: wholeNumber
                          ? IconButton(
                              key: ValueKey('skill-decrease-$key'),
                              tooltip: 'Decrease $label',
                              padding: EdgeInsets.zero,
                              onPressed:
                                  value != null && value > (limits?.$1 ?? 0)
                                  ? () => _stepWholeNumber(key, -1)
                                  : null,
                              icon: const Icon(Icons.remove, size: 18),
                            )
                          : null,
                      suffixIcon: wholeNumber
                          ? IconButton(
                              key: ValueKey('skill-increase-$key'),
                              tooltip: 'Increase $label',
                              padding: EdgeInsets.zero,
                              onPressed:
                                  value != null &&
                                      value < (limits?.$2 ?? double.infinity)
                                  ? () => _stepWholeNumber(key, 1)
                                  : null,
                              icon: const Icon(Icons.add, size: 18),
                            )
                          : null,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      errorText: _numberError(key),
                      helperText: enabled ? helper : disabledNote,
                      helperMaxLines: 3,
                    ),
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
            ),
            if (limits != null &&
                value != null &&
                value.isFinite &&
                const [
                  'weaponDisplayScale',
                  'pickupDisplayScale',
                  'effectDisplayScale',
                  'weaponGripInset',
                  'weaponGripSide',
                  'weaponGripRotation',
                  'projectileSize',
                  'handEffectScale',
                  'meleeReach',
                  'shellSize',
                ].contains(key))
              Slider(
                value: value.clamp(limits.$1, limits.$2),
                min: limits.$1,
                max: limits.$2,
                label: value.toStringAsFixed(2),
                onChanged: (v) =>
                    setState(() => _numbers[key]!.text = v.toStringAsFixed(2)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final compatibilityIssues = result?.compatibilityIssues ?? const <String>[];
    final performanceIssues = result?.performanceIssues ?? const <String>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: ScaffoldMessenger(
          key: _saveMessages,
          child: DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: Text('Edit ${widget.skill.name}'),
                bottom: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Identity'),
                    Tab(text: 'Damage & Timing'),
                    Tab(text: 'Appearance'),
                    Tab(text: 'Callouts & Sounds'),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    key: const ValueKey('skill-settings-info'),
                    tooltip: 'Skill settings guide',
                    onPressed: _showInfo,
                    icon: const Icon(Icons.info_outline),
                  ),
                  TextButton(
                    key: const ValueKey('save-skill'),
                    onPressed:
                        _saving ||
                            result == null ||
                            compatibilityIssues.isNotEmpty ||
                            _payloadProblem(result) != null
                        ? null
                        : _saveEditedSkill,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
              bottomNavigationBar: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('preview-skill'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: result == null ? null : _previewSkill,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline),
                                Text(
                                  'Preview',
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('demo-skill'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed:
                              result == null ||
                                  compatibilityIssues.isNotEmpty ||
                                  _payloadProblem(result) != null
                              ? null
                              : _demoSkill,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.science_outlined),
                                Text(
                                  'Skill Demo',
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('test-skill-live'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: result == null ? null : _testInLiveArena,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_esports_outlined),
                                Text(
                                  'Live Arena',
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('preview-skill-finisher'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          onPressed: result?.canDamage == true
                              ? _previewFinisher
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie_filter_outlined),
                                Text(
                                  'Finisher',
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              body: TabBarView(
                children: [
                  ListView(
                    key: PageStorageKey(
                      'skill-editor-identity-$_resetGeneration',
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section('Identity', 'Name, category and availability.'),
                      if (_numbers.keys.any((key) => _numberError(key) != null))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Check these values: ${_numbers.keys.where((key) => _numberError(key) != null).join(", ")}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      _fixedRow(
                        'Skill name',
                        TextField(
                          controller: _name,
                          maxLength: 40,
                          decoration: const InputDecoration(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      _fixedRow(
                        'Description',
                        TextField(
                          key: const ValueKey('skill-description'),
                          controller: _description,
                          onChanged: (_) =>
                              setState(() => _descriptionOverride = true),
                          maxLength: SkillDefinition.maxDescriptionLength,
                          minLines: 2,
                          maxLines: 3,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            hintText: 'Shown on the skill card',
                            helperMaxLines: 3,
                            helperText: widget.skill.custom
                                ? null
                                : 'Saving a built-in skill stores its current numbers; '
                                      'Edit power-up numbers (Legacy) will no longer change it.',
                          ),
                        ),
                      ),
                      _fixedRow(
                        'Category',
                        DropdownButtonFormField<SkillCategory>(
                          isExpanded: true,
                          key: const ValueKey('skill-category'),
                          initialValue: _category,
                          decoration: InputDecoration(
                            helperText:
                                'Purpose: ${result?.purpose.name ?? widget.skill.purpose.name}',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: SkillCategory.weapon,
                              child: Text('Weapon'),
                            ),
                            DropdownMenuItem(
                              value: SkillCategory.powerUp,
                              child: Text('Power-up'),
                            ),
                            DropdownMenuItem(
                              value: SkillCategory.trap,
                              child: Text('Trap'),
                            ),
                            DropdownMenuItem(
                              value: SkillCategory.arenaTrap,
                              child: Text('Arena trap'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _category = value!),
                        ),
                      ),
                      if (_rarity != null) ...[
                        const SizedBox(height: 8),
                        _fixedRow(
                          'Item rarity',
                          DropdownButtonFormField<PowerUpRarity>(
                            isExpanded: true,
                            key: const ValueKey('skill-item-rarity'),
                            initialValue: _rarity,
                            decoration: InputDecoration(
                              helperText: widget.skill.custom
                                  ? 'This skill\'s own tier: its color and how often it appears. '
                                        'The built-in ${widget.skill.baseKind.label} keeps its own.'
                                  : 'Controls how often this weapon or power-up appears.',
                              helperMaxLines: 3,
                            ),
                            items: [
                              for (final rarity in PowerUpRarity.values)
                                DropdownMenuItem(
                                  value: rarity,
                                  child: Text(rarity.label),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              // A custom skill's callout style moves with its tier unless it was set
                              // apart from the tier.
                              if (widget.skill.custom &&
                                  value != null &&
                                  _rarity != null &&
                                  _calloutStyle.index == _rarity!.index) {
                                _calloutStyle =
                                    SkillCalloutStyle.values[value.index];
                              }
                              _rarity = value;
                            }),
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const ValueKey('restore-skill-defaults'),
                          onPressed: _restoreDefaults,
                          icon: const Icon(Icons.restore),
                          label: const Text('Restore defaults'),
                        ),
                      ),
                      if (widget.skill.custom)
                        SwitchListTile(
                          key: const ValueKey('skill-enabled'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active in matches'),
                          subtitle: Text(
                            _enabled
                                ? 'Available as an independent skill using ${widget.skill.baseKind.label} as its visual template.'
                                : 'Saved but unavailable in matches.',
                          ),
                          value: _enabled,
                          onChanged: (value) =>
                              setState(() => _enabled = value),
                        ),
                      ..._combineSection(result),
                      _section(
                        'Behavior',
                        'Choose when the skill activates and what it does.',
                      ),
                      if (widget.skill.isComposed) ...[
                        _fixedRow(
                          'Trigger',
                          DropdownButtonFormField<SkillTrigger>(
                            isExpanded: true,
                            key: const ValueKey('skill-trigger'),
                            initialValue: _trigger,
                            decoration: const InputDecoration(),
                            items: [
                              for (final value in SkillTrigger.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _trigger = value;
                              if ((value == SkillTrigger.damageTaken ||
                                      value == SkillTrigger.elimination) &&
                                  (_double('cooldown') ?? 0) < 0.1) {
                                _numbers['cooldown']!.text = '1';
                              }
                            }),
                          ),
                        ),
                        if (_trigger == SkillTrigger.timer) ...[
                          const SizedBox(height: 12),
                          _number(
                            'triggerInterval',
                            'Trigger every',
                            suffix: 's',
                          ),
                        ],
                        const SizedBox(height: 12),
                        _fixedRow(
                          'Targeting',
                          DropdownButtonFormField<SkillTargeting>(
                            isExpanded: true,
                            key: const ValueKey('skill-targeting'),
                            initialValue: _targeting,
                            decoration: const InputDecoration(),
                            items: [
                              for (final value in SkillTargeting.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _targeting = value),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fixedRow(
                          'Delivery',
                          DropdownButtonFormField<SkillDelivery>(
                            isExpanded: true,
                            key: const ValueKey('skill-delivery'),
                            initialValue: _delivery,
                            decoration: const InputDecoration(),
                            items: [
                              for (final value in SkillDelivery.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _delivery = value),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _fixedRow(
                          'Effect',
                          DropdownButtonFormField<SkillEffectType>(
                            isExpanded: true,
                            key: const ValueKey('skill-effect-type'),
                            initialValue: _effectType,
                            decoration: const InputDecoration(),
                            items: [
                              for (final value in SkillEffectType.values)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              final wasRecovery =
                                  _effectType == SkillEffectType.heal;
                              _effectType = value;
                              if (value == SkillEffectType.heal &&
                                  !wasRecovery) {
                                _bubbleType = SkillBubbleType.speech;
                              } else if (value != SkillEffectType.heal &&
                                  wasRecovery) {
                                _bubbleType = SkillBubbleType.shout;
                              }
                            }),
                          ),
                        ),
                        if (_category == SkillCategory.weapon) ...[
                          const SizedBox(height: 4),
                          SwitchListTile.adaptive(
                            key: const ValueKey('skill-weapon-healing'),
                            contentPadding: EdgeInsets.zero,
                            value: _usesEffect(SkillEffectType.heal),
                            onChanged: (value) => setState(() {
                              if (value) {
                                if (_effectType != SkillEffectType.heal) {
                                  _secondaryEffectType = SkillEffectType.heal;
                                }
                              } else if (_secondaryEffectType ==
                                  SkillEffectType.heal) {
                                _secondaryEffectType = null;
                              } else if (_effectType == SkillEffectType.heal) {
                                _effectType = SkillEffectType.damage;
                              }
                            }),
                            title: const Text('Healing effect'),
                            subtitle: const Text(
                              'Off by default for weapons. Turn on only for a weapon that should also heal.',
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _fixedRow(
                          'Secondary effect',
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            key: const ValueKey('skill-secondary-effect-type'),
                            initialValue: _secondaryEffectType?.name ?? 'none',
                            decoration: const InputDecoration(
                              helperText: 'Runs after the primary effect.',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'none',
                                child: Text('None'),
                              ),
                              for (final value in SkillEffectType.values)
                                DropdownMenuItem(
                                  value: value.name,
                                  child: Text(value.name),
                                ),
                            ],
                            onChanged: (value) => setState(() {
                              _secondaryEffectType = value == 'none'
                                  ? null
                                  : SkillEffectType.values.firstWhere(
                                      (effect) => effect.name == value,
                                    );
                            }),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _number('repeatCount', 'Repeat count', suffix: 'times'),
                        _number(
                          'repeatInterval',
                          'Repeat interval',
                          suffix: 's',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'startDelay',
                                'Start delay',
                                suffix: 's',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _number(
                                'cooldown',
                                'Cooldown',
                                suffix: 's',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _number(
                          'tickInterval',
                          'DoT tick interval',
                          suffix: 's',
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (widget.skill.isComposed) ...[
                        _number(
                          'screenShake',
                          'Screen shake',
                          suffix: '0-1',
                          enabled: widget.library.skillsSetScreenShake,
                          disabledNote:
                              'Using the global screen shake (${widget.library.screenShake}). '
                              'Turn on "Let each skill set its own" in Built-in > Global to change it here.',
                        ),
                        if (_category == SkillCategory.weapon) ...[
                          const SizedBox(height: 12),
                          _fixedRow(
                            'Handedness',
                            DropdownButtonFormField<SkillHandedness>(
                              isExpanded: true,
                              key: const ValueKey('skill-handedness'),
                              initialValue: _handedness,
                              decoration: const InputDecoration(),
                              items: const [
                                DropdownMenuItem(
                                  value: SkillHandedness.carrierDefault,
                                  child: Text('Carrier default'),
                                ),
                                DropdownMenuItem(
                                  value: SkillHandedness.oneHanded,
                                  child: Text('One-handed'),
                                ),
                                DropdownMenuItem(
                                  value: SkillHandedness.twoHanded,
                                  child: Text('Two-handed'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _handedness = value!),
                            ),
                          ),
                        ],
                        if (compatibilityIssues.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Card(
                            key: const ValueKey('skill-compatibility-errors'),
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fix this combination',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  for (final issue in compatibilityIssues)
                                    Text('• $issue'),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (performanceIssues.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Card(
                            key: const ValueKey('skill-performance-warnings'),
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mayhem safety limit',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  ),
                                  for (final issue in performanceIssues)
                                    Text('• $issue'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  ListView(
                    key: PageStorageKey(
                      'skill-editor-damage-$_resetGeneration',
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section(
                        'Damage & timing',
                        'Values use the units shown beside each control.',
                      ),
                      if (_numbers.containsKey('arsenal') &&
                          (!widget.skill.isComposed ||
                              _usesEffect(SkillEffectType.damage)))
                        _number(
                          'arsenal',
                          'Initial / hit damage',
                          suffix: 'life',
                        ),
                      if (_numbers.containsKey('allOut') &&
                          (!widget.skill.isComposed ||
                              _usesEffect(SkillEffectType.damage)))
                        _number('allOut', 'All-Out damage', suffix: 'lines'),
                      if (_numbers.containsKey('dotArsenal') &&
                          _usesEffect(SkillEffectType.damageOverTime))
                        _number('dotArsenal', 'DoT', suffix: 'life/tick'),
                      if (_numbers.containsKey('dotAllOut') &&
                          _usesEffect(SkillEffectType.damageOverTime))
                        _number(
                          'dotAllOut',
                          'All-Out DoT',
                          suffix: 'lines/tick',
                        ),
                      if (_numbers.containsKey('duration'))
                        _number('duration', 'Duration', suffix: 's'),
                      if (_numbers.containsKey('count') &&
                          (!widget.skill.isComposed || _usesProjectileDelivery))
                        _number('count', 'Projectile / hit count'),
                      if (_numbers.containsKey('speed') &&
                          _usesProjectileDelivery)
                        _number('speed', 'Projectile speed', suffix: 'arena/s'),
                      if (_numbers.containsKey('spread') &&
                          _usesProjectileDelivery)
                        _number('spread', 'Spread', suffix: 'degrees'),
                      if (_numbers.containsKey('bounces') &&
                          _usesProjectileDelivery)
                        _number('bounces', 'Maximum bounces'),
                      if (widget.skill.isComposed ||
                          _explodesOnImpact ||
                          widget.skill.baseKind == PowerUpKind.timeBubble)
                        _number(
                          'range',
                          _explodesOnImpact ? 'Explosion radius' : 'Range',
                          suffix: 'arena ratio',
                        ),
                      if (_canSteerProjectile)
                        _number(
                          'projectileSpin',
                          'Projectile spin',
                          suffix: 'deg/s',
                        ),
                      if (widget.skill.isComposed ||
                          const [
                            PowerUpKind.speed,
                            PowerUpKind.overcharge,
                            PowerUpKind.repulsor,
                          ].contains(widget.skill.baseKind))
                        _number(
                          'effectStrength',
                          'Effect strength',
                          suffix: 'x',
                        ),
                      if (_showsHealing)
                        _number('healing', 'Healing', suffix: 'life'),
                      if (_showsShieldHits)
                        _number('shieldHits', 'Shield hits'),
                      if (_showsFreezeSettings)
                        _number(
                          'frozenDamageMultiplier',
                          'Frozen-target damage multiplier',
                          suffix: 'x',
                        ),
                      if (_showsFreezeSettings)
                        _number(
                          'frozenCollisionDamage',
                          'Frozen collision damage',
                          suffix: 'life',
                        ),
                      if (_canSteerProjectile)
                        SwitchListTile.adaptive(
                          key: const ValueKey('skill-homing'),
                          value: _homing,
                          onChanged: (value) => setState(() => _homing = value),
                          title: const Text('Homing projectile'),
                        ),
                      if (_canSteerProjectile)
                        SwitchListTile.adaptive(
                          key: const ValueKey('skill-return'),
                          value: _returnsToOrigin,
                          onChanged: (value) =>
                              setState(() => _returnsToOrigin = value),
                          title: const Text('Return to launch point'),
                        ),
                      if (_usesProjectileDelivery)
                        SwitchListTile.adaptive(
                          key: const ValueKey('skill-explosion'),
                          value: _explodesOnImpact,
                          onChanged: (value) =>
                              setState(() => _explodesOnImpact = value),
                          title: const Text('Explosion on impact'),
                          subtitle: const Text(
                            'Uses effect range, damage, color, sound, and shake.',
                          ),
                        ),
                      if (_category == SkillCategory.weapon)
                        SwitchListTile.adaptive(
                          key: const ValueKey('skill-track-opponent'),
                          value: _trackNearestOpponent,
                          onChanged: (value) =>
                              setState(() => _trackNearestOpponent = value),
                          title: const Text(
                            'Track nearest opponent while equipped',
                          ),
                          subtitle: const Text(
                            'Continuously turns the held artwork toward the nearest opponent.',
                          ),
                        ),
                      _number('knockback', 'Knockback strength', suffix: 'x'),
                      if (_strikesOnContact)
                        _number(
                          'meleeReach',
                          'Melee reach',
                          suffix: 'ball radii',
                          helper:
                              widget.skill.baseKind == PowerUpKind.orbitingFlail
                              ? 'The flail already reaches about 1.7 ball radii; higher values extend it.'
                              : null,
                        ),
                      if (widget.skill.baseKind == PowerUpKind.fireWall ||
                          widget.skill.baseKind == PowerUpKind.tornado) ...[
                        _number(
                          'handEffectScale',
                          'Hand effect scale',
                          suffix: 'x',
                        ),
                        _fixedRow(
                          'Hand effect color',
                          OutlinedButton.icon(
                            icon: Icon(Icons.circle, color: Color(_handColor)),
                            label: const Text('Choose'),
                            onPressed: () async {
                              final color = await showColorPicker(
                                context,
                                initialColor: Color(_handColor),
                                title: 'Hand effect color',
                              );
                              if (color != null && mounted) {
                                setState(() => _handColor = color.toARGB32());
                              }
                            },
                          ),
                        ),
                        _number(
                          'handEffectDuration',
                          'Hand effect duration',
                          suffix: 's',
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                  ListView(
                    key: PageStorageKey(
                      'skill-editor-appearance-$_resetGeneration',
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section(
                        'Appearance',
                        'Preview equipped artwork and projectiles at a shared reference size.',
                      ),
                      for (final slot in [
                        (
                          'Casting artwork',
                          _castingSpriteId,
                          (String? v) => _castingSpriteId = v,
                        ),
                        (
                          'Icon / held artwork',
                          _iconSpriteId,
                          (String? v) => _iconSpriteId = v,
                        ),
                        (
                          'Projectile artwork',
                          _projectileSpriteId,
                          (String? v) => _projectileSpriteId = v,
                        ),
                        (
                          'Impact / effect artwork',
                          _impactSpriteId,
                          (String? v) => _impactSpriteId = v,
                        ),
                      ])
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SpriteThumbnail(id: slot.$2),
                          title: Text(slot.$1),
                          subtitle: Text(
                            slot.$2 == null
                                ? 'Built-in art'
                                : SpriteRegistry.has(slot.$2!)
                                ? SpriteRegistry.displayLabel(slot.$2!)
                                : 'Missing sprite - using built-in art',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final picked = await selectSkillSprite(
                              context,
                              title: slot.$1,
                              current: slot.$2,
                            );
                            if (picked != null && mounted) {
                              setState(
                                () => slot.$3(picked.isEmpty ? null : picked),
                              );
                            }
                          },
                        ),
                      const SizedBox(height: 12),
                      _fixedRow(
                        'Artwork tint',
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              key: const ValueKey('skill-sprite-tint'),
                              icon: Icon(
                                Icons.palette_outlined,
                                color: Color(_spriteTint),
                              ),
                              label: Text(
                                _spriteTint == 0xFFFFFFFF
                                    ? 'Original'
                                    : 'Choose color',
                              ),
                              onPressed: () async {
                                final color = await showColorPicker(
                                  context,
                                  initialColor: Color(_spriteTint),
                                  title: 'Artwork tint',
                                );
                                if (color != null && mounted) {
                                  setState(
                                    () => _spriteTint = color.toARGB32(),
                                  );
                                }
                              },
                            ),
                            if (_spriteTint != 0xFFFFFFFF)
                              IconButton(
                                tooltip: 'Remove tint',
                                onPressed: () =>
                                    setState(() => _spriteTint = 0xFFFFFFFF),
                                icon: const Icon(Icons.restart_alt),
                              ),
                          ],
                        ),
                      ),
                      if (_castingSpriteId != null) ...[
                        const SizedBox(height: 12),
                        _section(
                          'Casting effect',
                          'Plays on the caster when the move starts, independently of hit artwork. Uses Sprite effect visuals.',
                        ),
                        _fixedRow(
                          'Follow active move',
                          Switch(
                            key: const ValueKey('casting-follows-active'),
                            value: _castingFollowsActive,
                            onChanged: (value) =>
                                setState(() => _castingFollowsActive = value),
                          ),
                        ),
                        const Text(
                          'Energy Wave, Shadow Clone, Raging Demon and Omnislash can follow the move until it ends. Other moves use the duration below.',
                        ),
                        _number(
                          'castingDuration',
                          'Casting duration',
                          suffix: 's',
                        ),
                        _number(
                          'castingScale',
                          'Casting artwork scale',
                          suffix: 'x',
                        ),
                      ],
                      const Text(
                        'Recolors this skill’s artwork, projectiles and effects. Original keeps the source colors.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListTile(
                              key: const ValueKey('skill-effect-color'),
                              title: const Text('Effect color'),
                              subtitle: const Text('Tap to choose a color'),
                              trailing: const Icon(Icons.palette_outlined),
                              onTap: () async {
                                final color = await showColorPicker(
                                  context,
                                  initialColor: Color(
                                    _colorValue ?? 0xFFFF6B6B,
                                  ),
                                  title: 'Effect color',
                                );
                                if (color != null && mounted) {
                                  setState(() {
                                    _effectColor.text =
                                        (color.toARGB32() & 0xFFFFFF)
                                            .toRadixString(16)
                                            .padLeft(6, '0');
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: CircleAvatar(
                              key: const ValueKey('skill-effect-color-preview'),
                              backgroundColor: Color(_colorValue ?? 0xFF000000),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _VisualModePreview(
                              label: 'Equipped item',
                              spriteId: _iconSpriteId,
                              tint: _spriteTint,
                              kind: widget.skill.baseKind,
                              mode: _sprite,
                              scale: _double('weaponDisplayScale') ?? 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _VisualModePreview(
                              tint: _spriteTint,
                              label: _usesProjectileDelivery
                                  ? 'Projectile'
                                  : 'Impact',
                              spriteId: _usesProjectileDelivery
                                  ? _projectileSpriteId
                                  : _impactSpriteId,
                              kind: widget.skill.baseKind,
                              mode: _usesProjectileDelivery ? _sprite : _effect,
                              impact: true,
                              scale: _double('projectileSize') ?? 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_category == SkillCategory.weapon) ...[
                        _number(
                          'weaponDisplayScale',
                          'Equipped display scale',
                          suffix: 'x',
                          enabled: widget.library.skillsSetWeaponDisplayScale,
                          disabledNote:
                              'Using the global equipped artwork size (${_SkillManagementScreenState._formatSeconds(widget.library.weaponDisplayScale)}x). '
                              'Turn on "Let each skill set its own" in Built-in > Global to change it here.',
                        ),
                        _number(
                          'weaponGripInset',
                          'Grip forward/back',
                          suffix: 'ball radius',
                          helper:
                              'Forward/back: positive pulls the weapon toward the ball, negative pushes it out.',
                        ),
                        _number(
                          'weaponGripSide',
                          'Grip sideways',
                          suffix: 'ball radius',
                        ),
                        _number(
                          'weaponGripRotation',
                          'Grip rotation',
                          suffix: 'degrees',
                        ),
                        _fixedRow(
                          'Artwork facing',
                          DropdownButton<SkillHeldFacing>(
                            key: const ValueKey('skill-held-facing'),
                            isExpanded: true,
                            value: _heldFacing,
                            items: [
                              for (final mode in SkillHeldFacing.values)
                                DropdownMenuItem(
                                  value: mode,
                                  child: Text(mode.label),
                                ),
                            ],
                            onChanged: (mode) =>
                                setState(() => _heldFacing = mode!),
                          ),
                        ),
                        if (widget.skill.baseKind.isWeapon)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OutlinedButton.icon(
                                key: const ValueKey('skill-grip-preview'),
                                onPressed: _previewGrip,
                                icon: const Icon(Icons.pan_tool_alt_outlined),
                                label: const Text('Preview grip'),
                              ),
                            ),
                          ),
                      ],
                      if (_usesProjectileDelivery)
                        _number(
                          'projectileSize',
                          'Projectile scale',
                          suffix: 'x',
                        ),
                      if (_showsShellSettings) ..._shellGroup(),
                      _number(
                        'pickupDisplayScale',
                        'Pickup artwork scale',
                        suffix: 'x',
                        enabled: widget.library.skillsSetPickupDisplayScale,
                        disabledNote:
                            'Using the global pickup artwork size (${_SkillManagementScreenState._formatSeconds(widget.library.pickupDisplayScale)}x). '
                            'Turn on "Let each skill set its own" in Built-in > Global to change it here.',
                      ),
                      if (widget.skill.isComposed ||
                          !const [
                            PowerUpKind.ghost,
                            PowerUpKind.magnet,
                          ].contains(widget.skill.baseKind))
                        _number(
                          'effectDisplayScale',
                          'Effect artwork scale',
                          suffix: 'x',
                          enabled: widget.library.skillsSetEffectDisplayScale,
                          disabledNote:
                              'Using the global effect artwork size (${_SkillManagementScreenState._formatSeconds(widget.library.effectDisplayScale)}x). '
                              'Turn on "Let each skill set its own" in Built-in > Global to change it here.',
                        ),
                      const SizedBox(height: 8),
                      _fixedRow(
                        'Projectile / item visual',
                        DropdownButtonFormField<SkillVisualMode>(
                          isExpanded: true,
                          initialValue: _sprite,
                          decoration: const InputDecoration(),
                          items: [
                            for (final mode in SkillVisualMode.values)
                              DropdownMenuItem(
                                value: mode,
                                child: _visualOption(mode),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _sprite = value!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fixedRow(
                        'Effect visuals',
                        DropdownButtonFormField<String>(
                          key: const ValueKey('skill-effect-visuals'),
                          isExpanded: true,
                          initialValue: _globalEffectVisuals
                              ? 'global'
                              : _effect.name,
                          decoration: const InputDecoration(
                            helperText:
                                'Applies to this skill’s effects. Unavailable sprite artwork uses the vector fallback.',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'global',
                              child: Text('Use global setting'),
                            ),
                            for (final mode in SkillVisualMode.values)
                              DropdownMenuItem(
                                value: mode.name,
                                child: _visualOption(mode),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _globalEffectVisuals = value == 'global';
                            if (!_globalEffectVisuals) {
                              _effect = SkillVisualMode.values.byName(value!);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  ListView(
                    key: PageStorageKey(
                      'skill-editor-callouts-$_resetGeneration',
                    ),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _section(
                        'Callouts & sound',
                        'What players see and hear when this skill activates.',
                      ),
                      _fixedRow(
                        'Yell',
                        TextField(
                          key: const ValueKey('skill-yell'),
                          controller: _yell,
                          maxLength: 60,
                          decoration: const InputDecoration(
                            helperText:
                                'Comic callout shown when the skill activates.',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      _CalloutPreview(
                        text: _yell.text.trim().isEmpty
                            ? 'BANG!'
                            : _yell.text.trim(),
                        style: _calloutStyle,
                        bubbleType: _bubbleType,
                      ),
                      const SizedBox(height: 8),
                      _fixedRow(
                        'Callout style',
                        DropdownButtonFormField<SkillCalloutStyle>(
                          isExpanded: true,
                          initialValue: _calloutStyle,
                          decoration: const InputDecoration(),
                          items: [
                            for (final style in SkillCalloutStyle.values)
                              DropdownMenuItem(
                                value: style,
                                child: Text(style.name),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _calloutStyle = value!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _fixedRow(
                        'Bubble shape',
                        DropdownButtonFormField<SkillBubbleType>(
                          isExpanded: true,
                          key: const ValueKey('skill-bubble-type'),
                          initialValue: _bubbleType,
                          decoration: const InputDecoration(),
                          items: const [
                            DropdownMenuItem(
                              value: SkillBubbleType.shout,
                              child: Text('Shout - attacks'),
                            ),
                            DropdownMenuItem(
                              value: SkillBubbleType.speech,
                              child: Text('Speech - recovery'),
                            ),
                            DropdownMenuItem(
                              value: SkillBubbleType.thought,
                              child: Text('Thought - quiet or psychic'),
                            ),
                            DropdownMenuItem(
                              value: SkillBubbleType.radio,
                              child: Text('Radio - tech or command'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _bubbleType = value!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _number(
                        'bubbleDuration',
                        'Speech bubble duration',
                        suffix: 's',
                        enabled: widget.library.skillsSetCallout,
                        disabledNote:
                            'Using the global callout duration (${widget.library.calloutSeconds} s). '
                            'Turn on "Let each skill set its own" in Built-in > Global to change it here.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: _fixedRow(
                              'Sound cue',
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    SkillDefinition.soundCues.contains(
                                      _sound.text,
                                    )
                                    ? _sound.text
                                    : 'shot',
                                decoration: const InputDecoration(),
                                items: [
                                  for (final cue in SkillDefinition.soundCues)
                                    DropdownMenuItem(
                                      value: cue,
                                      child: Text(cue),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _sound.text = value!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            key: const ValueKey('preview-skill-sound'),
                            onPressed: () => GameAudio.instance.previewSkillCue(
                              SkillDefinition.soundCues.contains(_sound.text)
                                  ? _sound.text
                                  : 'shot',
                            ),
                            icon: const CanvasActionGlyph(
                              CanvasActionGlyphType.play,
                              color: Colors.white,
                            ),
                            label: const Text('Play'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillPreviewDialog extends StatefulWidget {
  const _SkillPreviewDialog({required this.skill});

  final SkillDefinition skill;

  @override
  State<_SkillPreviewDialog> createState() => _SkillPreviewDialogState();
}

class _SkillPreviewDialogState extends State<_SkillPreviewDialog> {
  var _replay = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    GameAudio.instance.previewSkillCue(widget.skill.soundCue);
    setState(() => _replay++);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.skill.name),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(_replay),
          tween: Tween(begin: 0.72, end: 1),
          duration: const Duration(milliseconds: 650),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(widget.skill.effectColor),
                width: 5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(
                    widget.skill.effectColor,
                  ).withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 5,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: PowerUpIcon(
              widget.skill.baseKind,
              size: 64,
              tint: widget.skill.spriteTint,
              spriteId: widget.skill.iconSpriteId,
              useSettingsArtwork: false,
            ),
          ),
        ),
        const SizedBox(height: 18),
        _CalloutPreview(
          text: widget.skill.yell.isEmpty
              ? widget.skill.name
              : widget.skill.yell,
          style: widget.skill.calloutStyle,
          bubbleType: widget.skill.bubbleType,
        ),
      ],
    ),
    actions: [
      TextButton.icon(
        key: const ValueKey('replay-skill-preview'),
        onPressed: _play,
        icon: const Icon(Icons.replay),
        label: const Text('Replay'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  );
}

class _CalloutPreview extends StatelessWidget {
  const _CalloutPreview({
    required this.text,
    required this.style,
    required this.bubbleType,
  });
  final String text;
  final SkillCalloutStyle style;
  final SkillBubbleType bubbleType;

  @override
  Widget build(BuildContext context) {
    final colors = switch (style) {
      SkillCalloutStyle.normal => (Colors.white, Colors.black87),
      SkillCalloutStyle.rare => (
        const Color(0xFFDDF3FF),
        const Color(0xFF1976D2),
      ),
      SkillCalloutStyle.epic => (
        const Color(0xFFF1DEFF),
        const Color(0xFF8E24AA),
      ),
      SkillCalloutStyle.special => (
        const Color(0xFFFFE082),
        const Color(0xFFB71C1C),
      ),
    };
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('callout-style-preview'),
        constraints: const BoxConstraints(
          minWidth: 110,
          maxWidth: 280,
          minHeight: 68,
        ),
        child: CustomPaint(
          key: ValueKey('callout-bubble-${bubbleType.name}'),
          painter: _CalloutBubblePainter(
            bubbleType: bubbleType,
            fill: colors.$1,
            outline: colors.$2,
            strokeWidth: style == SkillCalloutStyle.special ? 4 : 2.5,
            glow: style == SkillCalloutStyle.special,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 25),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.$2,
                fontWeight: FontWeight.w900,
                fontSize: style == SkillCalloutStyle.special ? 18 : 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalloutBubblePainter extends CustomPainter {
  const _CalloutBubblePainter({
    required this.bubbleType,
    required this.fill,
    required this.outline,
    required this.strokeWidth,
    required this.glow,
  });

  final SkillBubbleType bubbleType;
  final Color fill;
  final Color outline;
  final double strokeWidth;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = switch (bubbleType) {
      SkillBubbleType.shout => _shoutPath(size),
      SkillBubbleType.speech => _speechPath(size),
      SkillBubbleType.thought => _thoughtPath(size),
      SkillBubbleType.radio => _radioPath(size),
    };
    if (glow) canvas.drawShadow(path, const Color(0xFFFF6D00), 10, true);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _speechPath(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 5, size.width - 16, size.height - 25),
        const Radius.circular(18),
      ),
    )
    ..moveTo(size.width * 0.68, size.height - 21)
    ..lineTo(size.width * 0.79, size.height - 3)
    ..lineTo(size.width * 0.62, size.height - 20)
    ..close();

  Path _thoughtPath(Size size) => Path()
    ..addOval(Rect.fromLTWH(8, 3, size.width - 16, size.height - 28))
    ..addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.72, size.height - 16),
        radius: 6,
      ),
    )
    ..addOval(
      Rect.fromCircle(
        center: Offset(size.width * 0.78, size.height - 5),
        radius: 3,
      ),
    );

  Path _radioPath(Size size) => Path()
    ..moveTo(20, 5)
    ..lineTo(size.width - 20, 5)
    ..lineTo(size.width - 7, 18)
    ..lineTo(size.width - 7, size.height - 23)
    ..lineTo(size.width - 22, size.height - 8)
    ..lineTo(22, size.height - 8)
    ..lineTo(7, size.height - 23)
    ..lineTo(7, 18)
    ..close();

  Path _shoutPath(Size size) {
    final center = Offset(size.width / 2, (size.height - 8) / 2);
    final path = Path();
    const points = 24;
    for (var i = 0; i < points; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / points;
      final outer = i.isEven;
      final point =
          center +
          Offset(
            math.cos(angle) * size.width * (outer ? 0.48 : 0.40),
            math.sin(angle) * size.height * (outer ? 0.46 : 0.34),
          );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _CalloutBubblePainter oldDelegate) =>
      bubbleType != oldDelegate.bubbleType ||
      fill != oldDelegate.fill ||
      outline != oldDelegate.outline ||
      strokeWidth != oldDelegate.strokeWidth ||
      glow != oldDelegate.glow;
}

class _VisualModePreview extends StatelessWidget {
  const _VisualModePreview({
    required this.label,
    required this.kind,
    required this.mode,
    this.impact = false,
    this.scale = 1,
    this.tint = 0xFFFFFFFF,
    this.spriteId,
  });

  final String label;
  final PowerUpKind kind;
  final SkillVisualMode mode;
  final bool impact;
  final double scale;
  final int tint;
  final String? spriteId;

  @override
  Widget build(BuildContext context) {
    final visualSize = (32 * scale).clamp(12.0, 64.0);
    return Container(
      key: ValueKey('visual-preview-${impact ? "impact" : "item"}'),
      height: 132,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 32,
            child: Center(
              child: Text(
                '$label · ${mode.name}',
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (impact)
                  Icon(
                    Icons.brightness_7,
                    size: 52,
                    color: PowerUpPainter.colorOf(kind).withValues(alpha: 0.3),
                  ),
                mode == SkillVisualMode.sprite
                    ? PowerUpIcon(
                        kind,
                        size: visualSize,
                        projectile: impact,
                        tint: tint,
                        spriteId: spriteId,
                        useSettingsArtwork: false,
                      )
                    : SkillArtworkTint.widget(
                        tint,
                        CustomPaint(
                          size: Size.square(visualSize),
                          painter: _VectorSkillPreview(kind),
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

class _VectorSkillPreview extends CustomPainter {
  const _VectorSkillPreview(this.kind);
  final PowerUpKind kind;

  @override
  void paint(Canvas canvas, Size size) => PowerUpPainter.drawGlyph(
    canvas,
    kind,
    size.center(Offset.zero),
    size.shortestSide * 0.34,
  );

  @override
  bool shouldRepaint(_VectorSkillPreview oldDelegate) =>
      oldDelegate.kind != kind;
}

/// A landed shell as the arena draws it ([PowerUpPainter.paintShellCasing]), level and centered, for a
/// reference ball radius that keeps a 10x shell inside the box.
class _ShellPreviewPainter extends CustomPainter {
  _ShellPreviewPainter({required this.spriteId, required this.size});

  final String? spriteId;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    PowerUpPainter.paintShellCasing(
      canvas,
      ShellCasing(
        position: box.center(Offset.zero),
        velocity: Offset.zero,
        angle: 0,
        spriteId: spriteId,
        size: size,
      ),
      box.shortestSide * 0.11,
    );
  }

  @override
  bool shouldRepaint(_ShellPreviewPainter oldDelegate) =>
      oldDelegate.spriteId != spriteId || oldDelegate.size != size;
}
