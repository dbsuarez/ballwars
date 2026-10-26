import 'package:flutter/material.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/presentation/power_up_painter.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/harpoon_cinematic.dart';
import '../../ball_management/domain/custom_ball.dart';
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
                  initialValue: carrier,
                  decoration: const InputDecoration(
                    labelText: 'Carrier slot and icon',
                    helperText: 'The new behavior replaces this arena pickup.',
                  ),
                  items: [
                    for (final kind in PowerUpKind.values)
                      DropdownMenuItem(value: kind, child: Text(kind.label)),
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
    setState(() => _library = _library.withDefinition(draft, widget.tuning));
    await _edit(draft);
  }

  Widget _list(bool custom, {String? category}) {
    final query = _query.trim().toLowerCase();
    final skills =
        _library
            .all(widget.tuning)
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
            leading: PowerUpIcon(skill.baseKind, size: 38),
            title: Text(skill.name),
            subtitle: Text(
              '${skill.baseKind.isWeapon
                  ? "Weapon"
                  : skill.baseKind.isTrap
                  ? "Trap"
                  : "Power-up"}'
              '${details.isEmpty ? "" : " • ${details.join(" • ")}"}'
              '${skill.custom && skill.enabled ? "\nReplaces ${skill.baseKind.label} in matches" : ""}',
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

  static String _categoryOf(SkillDefinition skill) => skill.baseKind.isWeapon
      ? 'Weapons'
      : skill.baseKind.isTrap
      ? 'Traps'
      : 'Power-ups';

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
              _list(false, category: 'Traps'),
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
                'Built-in edits affect gameplay immediately. Activate a custom variant to replace its base skill; '
                'only one variant per base skill can be active at a time.',
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
    if (widget.skill.isComposed)
      'repeatCount': TextEditingController(text: '${widget.skill.repeatCount}'),
    if (widget.skill.isComposed)
      'repeatInterval': TextEditingController(
        text: '${widget.skill.repeatIntervalSeconds}',
      ),
    'knockback': TextEditingController(text: '${widget.skill.knockback}'),
  };
  late SkillVisualMode _sprite = widget.skill.spriteMode;
  late SkillVisualMode _effect = widget.skill.effectMode;
  late bool _enabled = widget.skill.enabled;
  late SkillTrigger? _trigger = widget.skill.trigger;
  late SkillTargeting? _targeting = widget.skill.targeting;
  late SkillDelivery? _delivery = widget.skill.delivery;
  late SkillEffectType? _effectType = widget.skill.effectType;
  late SkillEffectType? _secondaryEffectType = widget.skill.secondaryEffectType;
  late SkillCalloutStyle _calloutStyle = widget.skill.calloutStyle;
  late final _yell = TextEditingController(text: widget.skill.yell);
  late final _sound = TextEditingController(text: widget.skill.soundCue);

  @override
  void dispose() {
    _name.dispose();
    _sound.dispose();
    _yell.dispose();
    for (final controller in _numbers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _double(String key) => double.tryParse(_numbers[key]?.text ?? '');
  int? _int(String key) => int.tryParse(_numbers[key]?.text ?? '');

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
      _name.text = defaults.name;
      _enabled = defaults.enabled;
      _sprite = defaults.spriteMode;
      _effect = defaults.effectMode;
      _trigger = defaults.trigger;
      _targeting = defaults.targeting;
      _delivery = defaults.delivery;
      _effectType = defaults.effectType;
      _secondaryEffectType = defaults.secondaryEffectType;
      _calloutStyle = defaults.calloutStyle;
      _sound.text = defaults.soundCue;
      _yell.text = defaults.yell;
      number('arsenal', defaults.arsenalDamage);
      number('allOut', defaults.allOutDamage);
      number('duration', defaults.durationSeconds);
      number('count', defaults.projectileCount);
      number('speed', defaults.projectileSpeed);
      number('spread', defaults.spreadDegrees);
      number('bounces', defaults.maxBounces);
      number('knockback', defaults.knockback);
      number('repeatCount', defaults.repeatCount);
      number('repeatInterval', defaults.repeatIntervalSeconds);
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
                    onHookFired: () =>
                        GameAudio.instance.skillCue(skill.soundCue),
                    onImpact: GameAudio.instance.hit,
                    onFinished: () => Navigator.of(previewContext).maybePop(),
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
    );
  }

  void _showInfo() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Skill settings guide'),
      content: const SingleChildScrollView(
        child: Text(
          'ACTIVE IN MATCHES replaces the built-in skill using the same carrier slot. Only one custom skill per carrier can be active.\n\n'
          'CARRIER SLOT AND ICON decides which arena pickup is replaced and supplies its category and icon.\n\n'
          'TRIGGER decides when the behavior runs: on pickup, after aiming and firing, or when colliding with another ball.\n\n'
          'TARGETING chooses the owner, nearest opponent, or every opponent.\n\n'
          'DELIVERY chooses an immediate effect, a traveling projectile, or an area effect.\n\n'
          'EFFECT decides what happens: damage, healing, freezing, speed, or knockback. Damage fields apply to Arsenal life and All-Out lines. Duration controls timed effects.\n\n'
          'SECONDARY EFFECT runs immediately after the primary effect. REPEAT COUNT includes the first activation; the interval controls the pause between later activations.\n\n'
          'ITEM and IMPACT visuals choose pixel-art sprites or vector rendering. Their previews update immediately.\n\n'
          'SOUND plays when the skill activates. Use the Play button to preview it. YELL is the comic callout shown by the ball.',
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
        _numbers.values.any((c) => double.tryParse(c.text) == null)) {
      return null;
    }
    return widget.skill.copyWith(
      name: _name.text.trim(),
      enabled: _enabled,
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
      trigger: _trigger,
      targeting: _targeting,
      delivery: _delivery,
      effectType: _effectType,
      secondaryEffectType: _secondaryEffectType,
      repeatCount: _int('repeatCount'),
      repeatIntervalSeconds: _double('repeatInterval'),
      yell: _yell.text,
      calloutStyle: _calloutStyle,
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
    final compatibilityIssues = result?.compatibilityIssues ?? const <String>[];
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
              IconButton(
                key: const ValueKey('skill-settings-info'),
                tooltip: 'Skill settings guide',
                onPressed: _showInfo,
                icon: const Icon(Icons.info_outline),
              ),
              TextButton(
                key: const ValueKey('save-skill'),
                onPressed: result == null || compatibilityIssues.isNotEmpty
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const ValueKey('restore-skill-defaults'),
                  onPressed: _restoreDefaults,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore defaults'),
                ),
              ),
              _CalloutPreview(
                text: _yell.text.trim().isEmpty ? 'BANG!' : _yell.text.trim(),
                style: _calloutStyle,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<SkillCalloutStyle>(
                initialValue: _calloutStyle,
                decoration: const InputDecoration(labelText: 'Callout style'),
                items: [
                  for (final style in SkillCalloutStyle.values)
                    DropdownMenuItem(value: style, child: Text(style.name)),
                ],
                onChanged: (value) => setState(() => _calloutStyle = value!),
              ),
              const SizedBox(height: 12),
              if (widget.skill.custom)
                SwitchListTile(
                  key: const ValueKey('skill-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active in matches'),
                  subtitle: Text(
                    _enabled
                        ? 'Replaces the built-in ${widget.skill.baseKind.label} skill.'
                        : 'Saved as an inactive variant.',
                  ),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              if (widget.skill.isComposed) ...[
                DropdownButtonFormField<SkillTrigger>(
                  key: const ValueKey('skill-trigger'),
                  initialValue: _trigger,
                  decoration: const InputDecoration(labelText: 'Trigger'),
                  items: [
                    for (final value in SkillTrigger.values)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) => setState(() => _trigger = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SkillTargeting>(
                  key: const ValueKey('skill-targeting'),
                  initialValue: _targeting,
                  decoration: const InputDecoration(labelText: 'Targeting'),
                  items: [
                    for (final value in SkillTargeting.values)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) => setState(() => _targeting = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SkillDelivery>(
                  key: const ValueKey('skill-delivery'),
                  initialValue: _delivery,
                  decoration: const InputDecoration(labelText: 'Delivery'),
                  items: [
                    for (final value in SkillDelivery.values)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) => setState(() => _delivery = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SkillEffectType>(
                  key: const ValueKey('skill-effect-type'),
                  initialValue: _effectType,
                  decoration: const InputDecoration(labelText: 'Effect'),
                  items: [
                    for (final value in SkillEffectType.values)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) => setState(() => _effectType = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('skill-secondary-effect-type'),
                  initialValue: _secondaryEffectType?.name ?? 'none',
                  decoration: const InputDecoration(
                    labelText: 'Secondary effect',
                    helperText: 'Runs after the primary effect.',
                  ),
                  items: [
                    const DropdownMenuItem(value: 'none', child: Text('None')),
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
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          for (final issue in compatibilityIssues)
                            Text('• $issue'),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              TextField(
                key: const ValueKey('skill-yell'),
                controller: _yell,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Yell',
                  helperText: 'Comic callout shown when the skill activates.',
                ),
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
              Row(
                children: [
                  Expanded(
                    child: _VisualModePreview(
                      label: 'Item',
                      kind: widget.skill.baseKind,
                      mode: _sprite,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VisualModePreview(
                      label: 'Impact',
                      kind: widget.skill.baseKind,
                      mode: _effect,
                      impact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const ValueKey('preview-skill-finisher'),
                onPressed:
                    (widget.skill.effectType == SkillEffectType.damage ||
                        (widget.skill.arsenalDamage ?? 0) > 0)
                    ? _previewFinisher
                    : null,
                icon: const Icon(Icons.movie_filter_outlined),
                label: Text(
                  (widget.skill.effectType == SkillEffectType.damage ||
                          (widget.skill.arsenalDamage ?? 0) > 0)
                      ? 'Preview finisher'
                      : 'No finisher for non-damaging skill',
                ),
              ),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue:
                          SkillDefinition.soundCues.contains(_sound.text)
                          ? _sound.text
                          : 'shot',
                      decoration: const InputDecoration(labelText: 'Sound cue'),
                      items: [
                        for (final cue in SkillDefinition.soundCues)
                          DropdownMenuItem(value: cue, child: Text(cue)),
                      ],
                      onChanged: (value) => _sound.text = value!,
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
                    icon: const Text('▶', style: TextStyle(fontSize: 18)),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalloutPreview extends StatelessWidget {
  const _CalloutPreview({required this.text, required this.style});
  final String text;
  final SkillCalloutStyle style;

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
      child: Container(
        key: const ValueKey('callout-style-preview'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: colors.$1,
          border: Border.all(
            color: colors.$2,
            width: style == SkillCalloutStyle.special ? 4 : 2.5,
          ),
          borderRadius: BorderRadius.circular(
            style == SkillCalloutStyle.epic ? 4 : 12,
          ),
          boxShadow: style == SkillCalloutStyle.special
              ? const [BoxShadow(color: Color(0x88FF6D00), blurRadius: 10)]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: colors.$2,
            fontWeight: FontWeight.w900,
            fontSize: style == SkillCalloutStyle.special ? 18 : 15,
          ),
        ),
      ),
    );
  }
}

class _VisualModePreview extends StatelessWidget {
  const _VisualModePreview({
    required this.label,
    required this.kind,
    required this.mode,
    this.impact = false,
  });

  final String label;
  final PowerUpKind kind;
  final SkillVisualMode mode;
  final bool impact;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('visual-preview-${label.toLowerCase()}'),
    height: 92,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text('$label · ${mode.name}'),
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
                  ? PowerUpIcon(kind, size: 46)
                  : CustomPaint(
                      size: const Size.square(52),
                      painter: _VectorSkillPreview(kind),
                    ),
            ],
          ),
        ),
      ],
    ),
  );
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
