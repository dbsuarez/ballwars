import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';

/// Admin: edits the power-up numbers ([PowerUpConfig.fields], grouped) for everyone's Arsenal and All-Out
/// matches. Each field shows its default; Restore defaults puts every field back. Save pops the new
/// config (the Settings screen stores it); leaving without saving changes nothing.
class PowerUpTuningScreen extends StatefulWidget {
  final PowerUpConfig initial;

  const PowerUpTuningScreen({super.key, required this.initial});

  @override
  State<PowerUpTuningScreen> createState() => _PowerUpTuningScreenState();
}

class _PowerUpTuningScreenState extends State<PowerUpTuningScreen> {
  static Iterable<TuningField> get _legacyFields => PowerUpConfig.fields.where(
    (field) => !field.id.startsWith('tier.') &&
        (!field.id.startsWith('skill') || field.id == 'skillTrapsEnabled'),
  );

  late final Map<String, TextEditingController> _text = {
    for (final f in _legacyFields)
      f.id: TextEditingController(text: _format(f, widget.initial.value(f.id))),
  };

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  static String _format(TuningField f, num value) {
    if (f.integer) return '${value.round()}';
    // Keep small force/ratio defaults exact when the form is opened and saved
    // without edits (for example the 0.012 Gravity Well force).
    final s = value.toStringAsFixed(4);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String _unit(TuningField f) => switch (f.unit) {
    TuningUnit.seconds => 's',
    TuningUnit.percent => '%',
    _ => '',
  };

  static PowerUpKind? _kind(TuningField f) {
    final parts = f.id.split('.');
    if ((parts.first == 'dmg' || parts.first == 'lines') && parts.length == 2) {
      return PowerUpKind.values
          .where((kind) => kind.name == parts.last)
          .firstOrNull;
    }
    return switch (f.id) {
      'pellets' => PowerUpKind.shotgun,
      'rounds' => PowerUpKind.gatling,
      'arrows' => PowerUpKind.bow,
      'grenadeSpeed' => PowerUpKind.grenade,
      'bash' || 'lines.bash' || 'block' || 'keep' => PowerUpKind.shield,
      'heal' || 'maxLife' || 'appleLines' => PowerUpKind.apple,
      'speed' => PowerUpKind.speed,
      'freeze' => PowerUpKind.freeze,
      'ghost' => PowerUpKind.ghost,
      'blast' => PowerUpKind.mine,
      _ => null,
    };
  }

  // Explanations are available by tap and keyboard, not hover alone.
  static const Set<String> _trapSwitches = {
    'allTrapsDisabled', 'arenaTrapsEnabled', 'skillTrapsEnabled',
  };

  static const Map<String, String> _trapHelp = {
    'allTrapsDisabled':
        'Master override. Turning this on disables both automatic arena hazards and skill-generated traps, regardless of their individual settings. Turning it off restores the two independent selections.',
    'arenaTrapsEnabled':
        'Allows automatic arena hazards, including arena-theme hazards and periodic spike walls. Turning it off also clears existing automatic hazards. This does not disable traps created by skills.',
    'skillTrapsEnabled':
        'Allows trap skills and trap pickups. Turning it off prevents trap activations and cancels existing skill mines and composed trap effects. This does not disable automatic arena hazards.',
  };

  static void _showTrapHelp(BuildContext context, TuningField field) {
    final explanation = _trapHelp[field.id];
    if (explanation == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(field.label),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static IconData _genericIcon(TuningField f) => switch (f.id) {
    'firstSpawn' || 'spawnEvery' || 'trapStart' => Icons.schedule_rounded,
    'fieldSize' => Icons.radio_button_checked_rounded,
    'aim' => Icons.gps_fixed_rounded,
    'bulletSpeed' => Icons.trending_flat_rounded,
    _ => Icons.tune_rounded,
  };

  static Widget _fieldIcon(TuningField f, Color muted) {
    final kind = _kind(f);
    return kind == null
        ? Icon(_genericIcon(f), size: 23, color: muted)
        : PowerUpIcon(kind, size: 30);
  }

  /// The config the fields describe; null while one isn't a number.
  PowerUpConfig? get _config {
    var config = PowerUpConfig.defaults;
    for (final f in _legacyFields) {
      final v = num.tryParse(_text[f.id]!.text.trim());
      if (v == null || !v.isFinite) return null;
      config = config.withValue(f.id, v);
    }
    if (PowerUpRarity.values.every(
      (rarity) => config.rarityWeight(rarity) == 0,
    )) {
      return null;
    }
    return config;
  }

  void _restoreDefaults() {
    setState(() {
      for (final f in _legacyFields) {
        _text[f.id]!.text = _format(f, f.defaultValue);
      }
    });
  }

  Widget _fieldsForGroups(
    BuildContext context,
    Map<String, List<TuningField>> groups,
    Set<String> visibleGroups,
    PowerUpConfig? config,
  ) {
    final c = BallWarsColors.of(context);
    return SingleChildScrollView(
      key: PageStorageKey(visibleGroups.join('-')),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Place the master and independent trap switches together near the
          // top of Common, so all three remain accessible during edits.
          for (final entry in [
            if (visibleGroups.contains('Arena traps'))
              MapEntry('Arena traps', groups['Arena traps'] ?? <TuningField>[]),
            ...groups.entries.where((entry) => entry.key != 'Arena traps'),
          ])
            if (visibleGroups.contains(entry.key)) ...[
              Text(
                entry.key.toUpperCase(),
                style: AppText.mono(12, color: c.muted),
              ),
              const SizedBox(height: 8),
              for (final f in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 34,
                        child: _fieldIcon(f, c.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.label,
                              style: AppText.ui(
                                14,
                                FontWeight.w700,
                                color: _kind(f) == null
                                    ? c.text
                                    : (config ?? widget.initial)
                                              .rarityOf(_kind(f)!)
                                              ?.color ??
                                          c.text,
                              ),
                            ),
                            if (_trapHelp.containsKey(f.id))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  key: ValueKey('trap-help-${f.id}'),
                                  tooltip: 'Explain ${f.label}',
                                  icon: const Icon(Icons.help_outline_rounded),
                                  onPressed: () => _showTrapHelp(context, f),
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              _trapSwitches.contains(f.id)
                                  ? 'Default: ${f.defaultValue == 0 ? 'Off' : 'On'}'
                                  : 'Default ${_format(f, f.defaultValue)}${_unit(f)} - '
                                      '${_format(f, f.min)} to ${_format(f, f.max)}',
                              style: AppText.ui(
                                10,
                                FontWeight.w500,
                                color: c.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_trapSwitches.contains(f.id))
                        Switch(
                          key: ValueKey('tuning-${f.id}'),
                          value: _text[f.id]!.text == '1',
                          // Keep the independent selections editable even
                          // under the master override, so lifting it restores
                          // exactly what the admin selected.
                          onChanged: (enabled) => setState(() {
                            _text[f.id]!.text = enabled ? '1' : '0';
                          }),
                        )
                      else
                        SizedBox(
                          width: 88,
                          child: TextField(
                            key: ValueKey('tuning-${f.id}'),
                            controller: _text[f.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            textAlign: TextAlign.end,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              suffixText: _unit(f),
                              isDense: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final config = _config;
    final groups = <String, List<TuningField>>{};
    for (final f in _legacyFields) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    // As wide as Home's and Settings' column on big screens, so switching between them feels even.
    return ColoredBox(
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Legacy power-up numbers'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Common'),
                    Tab(text: 'Arsenal'),
                    Tab(text: 'All-Out'),
                  ],
                ),
              ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Text(
                      'Legacy settings remain active while Skill Management is built. Changes are saved for everyone and included in replays.',
                      style: AppText.ui(
                        13,
                        FontWeight.w500,
                        color: c.muted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _fieldsForGroups(context, groups, const {
                          'Rarity spawn weights',
                          'Spawning',
                          'Arena traps',
                          'Guns',
                          'Effects',
                        }, config),
                        _fieldsForGroups(context, groups, const {
                          'Damage - Arsenal (life)',
                        }, config),
                        _fieldsForGroups(context, groups, const {
                          'Damage - All-Out (lines)',
                        }, config),
                      ],
                    ),
                  ),
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
                          onPressed: _restoreDefaults,
                          child: const Text('Restore defaults'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: config == null
                              ? null
                              : () => Navigator.of(context).pop(config),
                          child: const Text('Save'),
                        ),
                      ),
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
