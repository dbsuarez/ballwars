import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../arena_simulation/domain/power_up_config.dart';

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
    for (final f in PowerUpConfig.fields) f.id: TextEditingController(text: _format(f, widget.initial.value(f.id))),
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
                  style: AppText.ui(13, FontWeight.w500, color: c.muted, height: 1.4),
                ),
                for (final entry in groups.entries) ...[
                  const SizedBox(height: 22),
                  Text(entry.key.toUpperCase(), style: AppText.mono(12, color: c.muted)),
                  const SizedBox(height: 8),
                  for (final f in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        key: ValueKey('tuning-${f.id}'),
                        controller: _text[f.id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: f.label,
                          suffixText: _unit(f),
                          isDense: true,
                          helperText:
                              'Default ${_format(f, f.defaultValue)}${_unit(f)} - ${_format(f, f.min)} to ${_format(f, f.max)}',
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                OutlinedButton(onPressed: _restoreDefaults, child: const Text('Restore defaults')),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: config == null ? null : () => Navigator.of(context).pop(config),
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
