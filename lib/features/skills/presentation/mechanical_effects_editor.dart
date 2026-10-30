import '../../../core/widgets/number_stepper.dart';
import 'package:flutter/material.dart';
import '../domain/skill_library.dart';

String effectStepLabel(SkillEffectType type) => switch (type) {
  SkillEffectType.damageOverTime => 'DoT',
  SkillEffectType.equipCarrier => 'Equip carrier',
  _ => '${type.name[0].toUpperCase()}${type.name.substring(1)}',
};

class MechanicalEffectsEditor extends StatefulWidget {
  const MechanicalEffectsEditor({
    super.key,
    required this.steps,
    this.defaults,
  });
  final List<SkillEffectStep> steps;
  final SkillDefinition? defaults;

  static Future<List<SkillEffectStep>?> show(
    BuildContext context,
    List<SkillEffectStep> steps, {
    SkillDefinition? defaults,
  }) => showDialog<List<SkillEffectStep>>(
    context: context,
    builder: (_) => MechanicalEffectsEditor(steps: steps, defaults: defaults),
  );

  @override
  State<MechanicalEffectsEditor> createState() =>
      _MechanicalEffectsEditorState();
}

class _MechanicalEffectsEditorState extends State<MechanicalEffectsEditor> {
  late final _drafts = widget.steps.map(_StepDraft.new).toList();
  int _selected = 0;
  String? _error;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _save() {
    final result = <SkillEffectStep>[];
    for (var i = 0; i < _drafts.length; i++) {
      try {
        result.add(_drafts[i].read());
      } on FormatException catch (e) {
        setState(() {
          _selected = i;
          _error = 'Step ${i + 1}: ${e.message}';
        });
        return;
      }
    }
    Navigator.pop(context, result);
  }

  Widget _row(String label, Widget control) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(flex: 4, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: control),
      ],
    ),
  );

  String _hint(String key, String fallback) {
    final s = widget.defaults;
    if (s == null || fallback != 'Skill default') return fallback;
    final value = switch (key) {
      'damage' =>
        _drafts[_selected].type == SkillEffectType.damageOverTime
            ? s.dotArsenalDamage ?? s.arsenalDamage
            : s.arsenalDamage,
      'threads' =>
        _drafts[_selected].type == SkillEffectType.damageOverTime
            ? s.dotAllOutDamage ?? s.allOutDamage
            : s.allOutDamage,
      'healing' => s.healing,
      'duration' => s.durationSeconds,
      'tick' => s.tickIntervalSeconds,
      'knockback' => s.knockback,
      'strength' => s.effectStrength,
      'shield_hits' => s.shieldHits,
      'frozen_multiplier' => s.frozenDamageMultiplier,
      'frozen_collision' => s.frozenCollisionDamage,
      _ => null,
    };
    return value == null ? fallback : '$value (skill)';
  }

  Widget _number(
    _StepDraft draft,
    String key,
    String label,
    String hint, {
    String? unit,
  }) => _row(
    label,
    TextField(
      key: ValueKey('step-$key'),
      controller: draft.fields[key],
      textAlign: TextAlign.right,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !{'threads', 'shield_hits'}.contains(key),
      ),
      decoration: numberStepperDecoration(
        controller: draft.fields[key]!,
        label: label,
        integer: {'threads', 'shield_hits'}.contains(key),
        step: {'threads', 'shield_hits'}.contains(key) ? 1 : .1,
        min: switch (key) {
          'target_range' => 5,
          'duration' || 'tick' => .1,
          'frozen_multiplier' => 1,
          _ => 0,
        },
        max: switch (key) {
          'threads' => 360,
          'shield_hits' => 20,
          'damage' || 'healing' => 500,
          'duration' => 60,
          'delay' || 'tick' || 'strength' => 10,
          'frozen_multiplier' => 5,
          'frozen_collision' => 200,
          _ => 100,
        },
        onChanged: () => setState(() {}),
        id: 'step-number-$key',
        decoration: InputDecoration(
          hintText: _hint(key, hint),
          suffixText: unit,
          isDense: true,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final draft = _drafts.isEmpty ? null : _drafts[_selected];
    final type = draft?.type;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 620,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mechanical effect steps',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Runs in order. Blank parameters use the skill default. Artwork does not change damage or reach.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < _drafts.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(
                                  '${i + 1}. ${effectStepLabel(_drafts[i].type)}',
                                ),
                                selected: _selected == i,
                                onSelected: (_) => setState(() {
                                  _selected = i;
                                  _error = null;
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add step',
                    icon: const Icon(Icons.add),
                    onPressed: _drafts.length >= SkillDefinition.maxEffectSteps
                        ? null
                        : () => setState(() {
                            _drafts.add(
                              _StepDraft(
                                const SkillEffectStep(
                                  type: SkillEffectType.damage,
                                ),
                              ),
                            );
                            _selected = _drafts.length - 1;
                          }),
                  ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: draft == null
                    ? const Center(
                        child: Text(
                          'No steps. Add one, or use the legacy effects.',
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Step ${_selected + 1} of ${_drafts.length}',
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Move earlier',
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: _selected == 0
                                      ? null
                                      : () => setState(() {
                                          final d = _drafts.removeAt(_selected);
                                          _selected--;
                                          _drafts.insert(_selected, d);
                                        }),
                                ),
                                IconButton(
                                  tooltip: 'Move later',
                                  icon: const Icon(Icons.arrow_forward),
                                  onPressed: _selected == _drafts.length - 1
                                      ? null
                                      : () => setState(() {
                                          final d = _drafts.removeAt(_selected);
                                          _selected++;
                                          _drafts.insert(_selected, d);
                                        }),
                                ),
                                IconButton(
                                  tooltip: 'Remove step',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => setState(() {
                                    _drafts.removeAt(_selected).dispose();
                                    _selected = _selected.clamp(
                                      0,
                                      (_drafts.length - 1).clamp(0, 7),
                                    );
                                  }),
                                ),
                              ],
                            ),
                            _row(
                              'Effect',
                              DropdownButtonFormField<SkillEffectType>(
                                key: ValueKey(
                                  'step-type-$_selected-${draft.type}',
                                ),
                                initialValue: draft.type,
                                isExpanded: true,
                                isDense: false,
                                items: [
                                  for (final value in SkillEffectType.values)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        effectStepLabel(value),
                                        maxLines: 2,
                                        softWrap: true,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => draft.type = value!),
                              ),
                            ),
                            _row(
                              'Target',
                              DropdownButtonFormField<EffectStepTarget>(
                                key: ValueKey(
                                  'step-target-$_selected-${draft.target}',
                                ),
                                initialValue: draft.target,
                                isExpanded: true,
                                isDense: false,
                                items: [
                                  for (final value in EffectStepTarget.values)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value.label,
                                        maxLines: 2,
                                        softWrap: true,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                ],
                                onChanged: (value) =>
                                    setState(() => draft.target = value!),
                              ),
                            ),
                            _number(
                              draft,
                              'delay',
                              'Wait after previous (s)',
                              '0',
                              unit: 's',
                            ),
                            _number(
                              draft,
                              'target_range',
                              'Target range',
                              'Unlimited',
                              unit: '% arena',
                            ),
                            const Divider(height: 24),
                            if ({
                              SkillEffectType.damage,
                              SkillEffectType.damageOverTime,
                            }.contains(type)) ...[
                              _number(
                                draft,
                                'damage',
                                'Arsenal damage',
                                'Skill default',
                                unit: 'HP',
                              ),
                              _number(
                                draft,
                                'threads',
                                'All-out damage',
                                'Skill default',
                                unit: 'threads',
                              ),
                              _number(
                                draft,
                                'knockback',
                                'Impact knockback',
                                'Skill default',
                              ),
                            ],
                            if (type == SkillEffectType.heal)
                              _number(
                                draft,
                                'healing',
                                'Healing',
                                'Skill default',
                              ),
                            if (type == SkillEffectType.shield)
                              _number(
                                draft,
                                'shield_hits',
                                'Blocked hits',
                                'Skill default',
                              ),
                            if ({
                              SkillEffectType.damageOverTime,
                              SkillEffectType.freeze,
                              SkillEffectType.stun,
                              SkillEffectType.speed,
                            }.contains(type))
                              _number(
                                draft,
                                'duration',
                                'Duration',
                                'Skill default',
                                unit: 's',
                              ),
                            if (type == SkillEffectType.freeze) ...[
                              _number(
                                draft,
                                'frozen_multiplier',
                                'Frozen damage multiplier',
                                'Skill default',
                              ),
                              _number(
                                draft,
                                'frozen_collision',
                                'Frozen collision damage',
                                'Skill default',
                              ),
                            ],
                            if (type == SkillEffectType.damageOverTime)
                              _number(
                                draft,
                                'tick',
                                'Tick interval',
                                'Skill default',
                                unit: 's',
                              ),
                            if ({
                              SkillEffectType.pull,
                              SkillEffectType.knockback,
                            }.contains(type))
                              _number(
                                draft,
                                'knockback',
                                'Force',
                                'Skill default',
                              ),
                            if ({
                              SkillEffectType.pull,
                              SkillEffectType.knockback,
                              SkillEffectType.speed,
                            }.contains(type))
                              _number(
                                draft,
                                'strength',
                                'Strength',
                                'Skill default',
                              ),
                            const SizedBox(height: 12),
                            const Text(
                              'Hit targets uses the original collision/activation targets. Nearest and All opponents are resolved when this step runs. Radius is measured from the caster; blank means unlimited.',
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Use steps'),
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

class _StepDraft {
  _StepDraft(SkillEffectStep step) : type = step.type, target = step.target {
    final json = step.toJson();
    for (final key in [
      'delay',
      'target_range',
      'damage',
      'threads',
      'healing',
      'shield_hits',
      'duration',
      'tick',
      'knockback',
      'strength',
      'frozen_multiplier',
      'frozen_collision',
    ]) {
      final value = json[key];
      fields[key] = TextEditingController(
        text: value == null
            ? ''
            : '${key == 'target_range' ? (value as num) * 100 : value}',
      );
    }
  }
  SkillEffectType type;
  EffectStepTarget target;
  final fields = <String, TextEditingController>{};
  SkillEffectStep read() {
    final json = <String, Object?>{'type': type.name, 'target': target.name};
    final active = <String>{
      'delay',
      'target_range',
      ...switch (type) {
        SkillEffectType.damage => {'damage', 'threads', 'knockback'},
        SkillEffectType.damageOverTime => {
          'damage',
          'threads',
          'knockback',
          'duration',
          'tick',
        },
        SkillEffectType.heal => {'healing'},
        SkillEffectType.shield => {'shield_hits'},
        SkillEffectType.freeze => {
          'duration',
          'frozen_multiplier',
          'frozen_collision',
        },
        SkillEffectType.stun => {'duration'},
        SkillEffectType.speed => {'duration', 'strength'},
        SkillEffectType.pull ||
        SkillEffectType.knockback => {'knockback', 'strength'},
        _ => <String>{},
      },
    };
    for (final entry in fields.entries) {
      if (!active.contains(entry.key)) continue;
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value == null || !value.isFinite) {
        throw FormatException('${entry.key} must be a number.');
      }
      if (entry.key == 'target_range' && (value < 5 || value > 100)) {
        throw const FormatException(
          'Target range must be 5 to 100 percent of the arena radius.',
        );
      }
      json[entry.key] = entry.key == 'target_range' ? value / 100 : value;
    }
    return SkillEffectStep.fromJson(json);
  }

  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
  }
}
