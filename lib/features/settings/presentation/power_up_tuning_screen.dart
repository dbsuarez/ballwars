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
  late final Map<String, TextEditingController> _text = {
    for (final f in PowerUpConfig.fields)
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
    final s = value.toStringAsFixed(2);
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

  static IconData _genericIcon(TuningField f) => switch (f.id) {
    'firstSpawn' || 'spawnEvery' => Icons.schedule_rounded,
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
    for (final f in PowerUpConfig.fields) {
      final v = num.tryParse(_text[f.id]!.text.trim());
      if (v == null || !v.isFinite) return null;
      config = config.withValue(f.id, v);
    }
    return config;
  }

  void _restoreDefaults() {
    setState(() {
      for (final f in PowerUpConfig.fields) {
        _text[f.id]!.text = _format(f, f.defaultValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = BallWarsColors.of(context);
    final config = _config;
    final groups = <String, List<TuningField>>{};
    for (final f in PowerUpConfig.fields) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }
    // As wide as Home's and Settings' column on big screens, so switching between them feels even.
    return ColoredBox(
      color: c.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Scaffold(
            appBar: AppBar(title: const Text('Power-up numbers')),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'For everyone\'s Arsenal and All-Out matches. Shared replays keep the numbers they were played '
                  'with. Values outside the allowed range are clamped.',
                  style: AppText.ui(
                    13,
                    FontWeight.w500,
                    color: c.muted,
                    height: 1.4,
                  ),
                ),
                for (final entry in groups.entries) ...[
                  const SizedBox(height: 22),
                  Text(
                    entry.key.toUpperCase(),
                    style: AppText.mono(12, color: c.muted),
                  ),
                  const SizedBox(height: 8),
                  for (final f in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                    color: c.text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Default ${_format(f, f.defaultValue)}${_unit(f)} - '
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
                          SizedBox(
                            width: 88,
                            child: TextField(
                              key: ValueKey('tuning-${f.id}'),
                              controller: _text[f.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                ],
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: _restoreDefaults,
                  child: const Text('Restore defaults'),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: config == null
                      ? null
                      : () => Navigator.of(context).pop(config),
                  child: const Text('Save for everyone'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
