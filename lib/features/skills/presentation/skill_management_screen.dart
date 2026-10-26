import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../domain/skill_library.dart';

class SkillManagementScreen extends StatefulWidget {
  const SkillManagementScreen({
    super.key,
    required this.initial,
    required this.tuning,
  });

  final SkillLibrary initial;
  final PowerUpConfig tuning;

  @override
  State<SkillManagementScreen> createState() => _SkillManagementScreenState();
}

class _SkillManagementScreenState extends State<SkillManagementScreen> {
  late SkillLibrary _library = widget.initial;
  String _query = '';

  Future<void> _edit(SkillDefinition skill) async {
    final edited = await showModalBottomSheet<SkillDefinition>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SkillEditor(skill: skill),
    );
    if (edited == null || !mounted) return;
    setState(() => _library = _library.withDefinition(edited, widget.tuning));
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
    setState(() => _library = _library.withDefinition(copy, widget.tuning));
    await _edit(copy);
  }

  Widget _list(bool custom) {
    final query = _query.trim().toLowerCase();
    final skills =
        _library
            .all(widget.tuning)
            .where((skill) => skill.custom == custom)
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
    if (skills.isEmpty) {
      return Center(
        child: Text(
          custom
              ? 'No custom skills yet. Duplicate a built-in skill to create one.'
              : 'No matching skills.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        final details = <String>[
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
            leading: PowerUpIcon(skill.baseKind, size: 38),
            title: Text(skill.name),
            subtitle: Text(
              '${skill.baseKind.isWeapon
                  ? "Weapon"
                  : skill.baseKind.isTrap
                  ? "Trap"
                  : "Power-up"}'
              '${details.isEmpty ? "" : " • ${details.join(" • ")}"}'
              '${skill.custom && !skill.enabled ? "\nDisabled until activated in a later runtime pass" : ""}',
            ),
            isThreeLine: skill.custom && !skill.enabled,
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

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Skill Management'),
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
                decoration: const InputDecoration(
                  labelText: 'Search skills',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                'Built-in damage, thread damage, supported durations and projectile counts affect gameplay now. '
                'Advanced motion and custom-skill activation are stored safely for the next runtime migration.',
                style: AppText.ui(
                  12,
                  FontWeight.w500,
                  color: c.muted,
                  height: 1.35,
                ),
              ),
            ),
            Expanded(child: TabBarView(children: [_list(false), _list(true)])),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
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
                    onPressed: () => Navigator.pop(context, _library),
                    child: const Text('Save for everyone'),
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
  const _SkillEditor({required this.skill});
  final SkillDefinition skill;

  @override
  State<_SkillEditor> createState() => _SkillEditorState();
}

class _SkillEditorState extends State<_SkillEditor> {
  late final _name = TextEditingController(text: widget.skill.name);
  late final Map<String, TextEditingController> _numbers = {
    if (widget.skill.arsenalDamage != null)
      'arsenal': TextEditingController(text: '${widget.skill.arsenalDamage}'),
    if (widget.skill.allOutDamage != null)
      'allOut': TextEditingController(text: '${widget.skill.allOutDamage}'),
    if (widget.skill.durationSeconds != null)
      'duration': TextEditingController(
        text: '${widget.skill.durationSeconds}',
      ),
    if (widget.skill.projectileCount != null)
      'count': TextEditingController(text: '${widget.skill.projectileCount}'),
    if (widget.skill.projectileSpeed != null)
      'speed': TextEditingController(text: '${widget.skill.projectileSpeed}'),
    if (widget.skill.spreadDegrees != null)
      'spread': TextEditingController(text: '${widget.skill.spreadDegrees}'),
    if (widget.skill.maxBounces != null)
      'bounces': TextEditingController(text: '${widget.skill.maxBounces}'),
    'knockback': TextEditingController(text: '${widget.skill.knockback}'),
  };
  late SkillVisualMode _sprite = widget.skill.spriteMode;
  late SkillVisualMode _effect = widget.skill.effectMode;
  late final _sound = TextEditingController(text: widget.skill.soundCue);

  @override
  void dispose() {
    _name.dispose();
    _sound.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _double(String key) => double.tryParse(_numbers[key]?.text ?? '');
  int? _int(String key) => int.tryParse(_numbers[key]?.text ?? '');

  SkillDefinition? get _result {
    if (_name.text.trim().isEmpty ||
        _numbers.values.any((c) => double.tryParse(c.text) == null)) {
      return null;
    }
    return widget.skill.copyWith(
      name: _name.text.trim(),
      arsenalDamage: _double('arsenal'),
      allOutDamage: _int('allOut'),
      durationSeconds: _double('duration'),
      projectileCount: _int('count'),
      projectileSpeed: _double('speed'),
      spreadDegrees: _double('spread'),
      maxBounces: _int('bounces'),
      knockback: _double('knockback'),
      spriteMode: _sprite,
      effectMode: _effect,
      soundCue: _sound.text.trim().isEmpty ? 'default' : _sound.text.trim(),
    );
  }

  Widget _number(String key, String label, {String? suffix}) => TextField(
    key: ValueKey('skill-field-$key'),
    controller: _numbers[key],
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    onChanged: (_) => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit ${widget.skill.name}'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: result == null
                    ? null
                    : () => Navigator.pop(context, result),
                child: const Text('Done'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Skill name'),
                onChanged: (_) => setState(() {}),
              ),
              if (_numbers.containsKey('arsenal'))
                _number('arsenal', 'Initial / hit damage', suffix: 'life'),
              if (_numbers.containsKey('allOut'))
                _number('allOut', 'All-Out damage', suffix: 'lines'),
              if (_numbers.containsKey('duration'))
                _number('duration', 'Duration', suffix: 's'),
              if (_numbers.containsKey('count'))
                _number('count', 'Projectile / hit count'),
              if (_numbers.containsKey('speed'))
                _number('speed', 'Projectile speed', suffix: 'arena/s'),
              if (_numbers.containsKey('spread'))
                _number('spread', 'Spread', suffix: 'degrees'),
              if (_numbers.containsKey('bounces'))
                _number('bounces', 'Maximum bounces'),
              _number('knockback', 'Knockback strength', suffix: 'x'),
              const SizedBox(height: 12),
              DropdownButtonFormField<SkillVisualMode>(
                initialValue: _sprite,
                decoration: const InputDecoration(
                  labelText: 'Projectile / item visual',
                ),
                items: [
                  for (final mode in SkillVisualMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.name)),
                ],
                onChanged: (value) => setState(() => _sprite = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<SkillVisualMode>(
                initialValue: _effect,
                decoration: const InputDecoration(
                  labelText: 'Impact / area effect',
                ),
                items: [
                  for (final mode in SkillVisualMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.name)),
                ],
                onChanged: (value) => setState(() => _effect = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sound,
                maxLength: 60,
                decoration: const InputDecoration(labelText: 'Sound cue ID'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
