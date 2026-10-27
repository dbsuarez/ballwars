import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/widgets/color_picker_dialog.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/game_audio.dart';
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
import '../domain/skill_library.dart';
import 'skill_artwork_tint.dart';

class SkillManagementScreen extends StatefulWidget {
  const SkillManagementScreen({
    super.key,
    required this.initial,
    required this.tuning,
    this.onSave,
  });

  final SkillLibrary initial;
  final PowerUpConfig tuning;
  final Future<void> Function(SkillManagementResult)? onSave;

  @override
  State<SkillManagementScreen> createState() => _SkillManagementScreenState();
}

class SkillManagementResult {
  const SkillManagementResult({required this.library, required this.tuning});

  final SkillLibrary library;
  final PowerUpConfig tuning;
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

  Future<void> _edit(SkillDefinition skill) async {
    final edited = await showModalBottomSheet<_SkillEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SkillEditor(
        skill: skill,
        rarity: _tuning.rarityOf(skill.baseKind),
        onSave: widget.onSave == null
            ? null
            : (edited) async {
                final tuning = edited.rarity == null
                    ? _tuning
                    : _tuning.withRarity(skill.baseKind, edited.rarity!);
                final library = _library.withDefinition(edited.skill, tuning);
                await widget.onSave!(
                  SkillManagementResult(library: library, tuning: tuning),
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
      if (edited.rarity != null) {
        _tuning = _tuning.withRarity(skill.baseKind, edited.rarity!);
      }
      _library = _library.withDefinition(edited.skill, _tuning);
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
            : _tuning.rarityOf(skill.baseKind)!.label;
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
        return Card(
          child: ListTile(
            minVerticalPadding: 12,
            leading: PowerUpIcon(
              skill.baseKind,
              size: 38,
              tint: skill.spriteTint,
            ),
            title: Text(
              skill.name,
              key: ValueKey('skill-name-${skill.id}'),
              style: TextStyle(
                color:
                    skill.resolvedCategory == SkillCategory.trap ||
                        skill.resolvedCategory == SkillCategory.arenaTrap
                    ? const Color(0xFFFFD54F)
                    : _tuning.rarityOf(skill.baseKind)?.color,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${_categoryLabel(skill.resolvedCategory)}'
              '${details.isEmpty ? "" : " • ${details.join(" • ")}"}'
              '${skill.custom && skill.enabled ? "\nIndependent skill using ${skill.baseKind.label} artwork" : ""}',
            ),
            isThreeLine: skill.custom && skill.enabled,
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

  Widget _builtInSkills() => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        const TabBar(
          key: ValueKey('built-in-skill-tabs'),
          tabs: [
            Tab(text: 'Weapons'),
            Tab(text: 'Power-ups'),
            Tab(text: 'Traps'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
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
                    onPressed: () =>
                        setState(() => _library = SkillLibrary.defaults),
                    child: const Text('Restore defaults'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      SkillManagementResult(library: _library, tuning: _tuning),
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
  const _SkillEditor({required this.skill, required this.rarity, this.onSave});
  final SkillDefinition skill;
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
    if (_saving || result == null || result.compatibilityIssues.isNotEmpty) {
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
    'bubbleDuration': TextEditingController(
      text: '${widget.skill.bubbleDurationSeconds}',
    ),
    'handEffectScale': TextEditingController(
      text: '${widget.skill.handEffectScale}',
    ),
    'handEffectDuration': TextEditingController(
      text: '${widget.skill.handEffectDurationSeconds}',
    ),
  };
  late SkillVisualMode _sprite = widget.skill.spriteMode;
  late SkillVisualMode _effect = widget.skill.effectMode;
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
  late final _sound = TextEditingController(text: widget.skill.soundCue);
  late int _handColor = widget.skill.handEffectColor;
  late int _spriteTint = widget.skill.spriteTint;
  int _resetGeneration = 0;

  @override
  void dispose() {
    _name.dispose();
    _sound.dispose();
    _yell.dispose();
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
      _enabled = defaults.enabled;
      _homing = defaults.homing;
      _returnsToOrigin = defaults.returnsToOrigin;
      _trackNearestOpponent = defaults.trackNearestOpponent;
      _sprite = defaults.spriteMode;
      _effect = defaults.effectMode;
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
      number('effectStrength', defaults.effectStrength);
      number('healing', defaults.healing);
      number('shieldHits', defaults.shieldHits);
      number('frozenDamageMultiplier', defaults.frozenDamageMultiplier);
      number('frozenCollisionDamage', defaults.frozenCollisionDamage);
      number('knockback', defaults.knockback);
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
                    visualMove: skill.baseKind.label,
                    artworkTint: skill.spriteTint,
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
      effectStrength: _double('effectStrength'),
      healing: _double('healing'),
      shieldHits: _int('shieldHits'),
      frozenDamageMultiplier: _double('frozenDamageMultiplier'),
      frozenCollisionDamage: _double('frozenCollisionDamage'),
      knockback: _double('knockback'),
      spriteMode: _sprite,
      effectMode: _effect,
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
    );
  }

  static const _limits = <String, (double, double)>{
    'weaponDisplayScale': (0.25, 3),
    'pickupDisplayScale': (0.25, 3),
    'effectDisplayScale': (0.25, 3),
    'weaponGripInset': (0, 1.5),
    'projectileSize': (0.1, 5),
    'screenShake': (0, 1),
    'knockback': (0, 100),
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
  };

  String? _numberError(String key) {
    final raw = _numbers[key]?.text ?? '';
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite) return 'Enter a number';
    if (value < 0 && key != 'projectileSpin') return 'Must be zero or more';
    if (const [
          'count',
          'allOut',
          'dotAllOut',
          'bounces',
          'repeatCount',
          'shieldHits',
        ].contains(key) &&
        value != value.roundToDouble()) {
      return 'Use a whole number';
    }
    final limits = _limits[key];
    if (limits != null && (value < limits.$1 || value > limits.$2)) {
      return '${limits.$1} to ${limits.$2}';
    }
    return null;
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

  Widget _number(String key, String label, {String? suffix}) {
    final limits = _limits[key];
    final value = _double(key);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            _fixedRow(
              label,
              TextField(
                key: ValueKey('skill-field-$key'),
                controller: _numbers[key],
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: suffix,
                  isDense: true,
                  border: const OutlineInputBorder(),
                  errorText: _numberError(key),
                ),
                onChanged: (_) => setState(() {}),
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
                  'projectileSize',
                  'handEffectScale',
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
                            compatibilityIssues.isNotEmpty
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
                          onPressed: result == null ? null : _previewSkill,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_outline),
                                Text('Preview'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('test-skill-live'),
                          onPressed: result == null ? null : _testInLiveArena,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_esports_outlined),
                                Text('Live Arena'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('preview-skill-finisher'),
                          onPressed: result?.canDamage == true
                              ? _previewFinisher
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.movie_filter_outlined),
                                Text('Finisher'),
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
                            decoration: const InputDecoration(
                              helperText:
                                  'Controls how often this weapon or power-up appears.',
                            ),
                            items: [
                              for (final rarity in PowerUpRarity.values)
                                DropdownMenuItem(
                                  value: rarity,
                                  child: Text(rarity.label),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _rarity = value),
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
                        Row(
                          children: [
                            Expanded(
                              child: _number(
                                'repeatCount',
                                'Repeat count',
                                suffix: 'times',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _number(
                                'repeatInterval',
                                'Repeat interval',
                                suffix: 's',
                              ),
                            ),
                          ],
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
                        _number('screenShake', 'Screen shake', suffix: '0-1'),
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
                        ),
                        _number(
                          'weaponGripInset',
                          'Grip inset',
                          suffix: 'ball radius',
                        ),
                      ],
                      if (_usesProjectileDelivery)
                        _number(
                          'projectileSize',
                          'Projectile scale',
                          suffix: 'x',
                        ),
                      _number(
                        'pickupDisplayScale',
                        'Pickup artwork scale',
                        suffix: 'x',
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
                      if (_explodesOnImpact ||
                          !widget.skill.isComposed &&
                              const [
                                PowerUpKind.grenade,
                                PowerUpKind.rocketLauncher,
                                PowerUpKind.mine,
                                PowerUpKind.phaseMine,
                                PowerUpKind.freeze,
                              ].contains(widget.skill.baseKind))
                        _fixedRow(
                          'Impact / area effect',
                          DropdownButtonFormField<SkillVisualMode>(
                            isExpanded: true,
                            initialValue: _effect,
                            decoration: const InputDecoration(),
                            items: [
                              for (final mode in SkillVisualMode.values)
                                DropdownMenuItem(
                                  value: mode,
                                  child: _visualOption(mode),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _effect = value!),
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
  });

  final String label;
  final PowerUpKind kind;
  final SkillVisualMode mode;
  final bool impact;
  final double scale;
  final int tint;

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
