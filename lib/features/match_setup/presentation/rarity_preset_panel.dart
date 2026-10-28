import 'package:flutter/material.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../domain/rarity_preset.dart';

class RarityPresetPanel extends StatelessWidget {
  const RarityPresetPanel({
    super.key,
    required this.preset,
    required this.customValues,
    required this.onPreset,
    required this.onWeight,
    required this.onReset,
    required this.odds,
    required this.error,
    required this.trapStartSeconds,
  });
  final RarityPreset preset;
  final List<String> customValues;
  final ValueChanged<RarityPreset> onPreset;
  final void Function(int index, String value) onWeight;
  final VoidCallback onReset;
  final RaritySpawnOdds? odds;
  final String? error;
  final double trapStartSeconds;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Power-up Rarity',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'About rarity odds',
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Power-up rarity'),
                    content: const Text(
                      'Weights select a tier among non-trap pickups, then an item within that tier. '
                      'The number of items affects which item you get, not how often its tier is selected. '
                      'Empty tiers and zero weights are excluded. Traps keep their existing separate chance. '
                      'The preview assumes an empty arena after traps start. Occupied pickups change the eligible pool during play.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(flex: 4, child: Text('Preset')),
              Expanded(
                flex: 6,
                child: DropdownButtonFormField<RarityPreset>(
                  key: const ValueKey('rarity-preset'),
                  isExpanded: true,
                  initialValue: preset,
                  decoration: const InputDecoration(isDense: true),
                  items: [
                    for (final value in RarityPreset.values)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) onPreset(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(preset.description),
          if (preset == RarityPreset.custom) ...[
            const SizedBox(height: 12),
            for (final tier in PowerUpRarity.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text('${tier.label} weight')),
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        key: ValueKey('rarity-weight-${tier.name}'),
                        initialValue: customValues[tier.index],
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => onWeight(tier.index, value),
                      ),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('rarity-reset-balanced'),
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset to Balanced'),
              ),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                error!,
                key: const ValueKey('rarity-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (odds != null && error == null) ...[
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.0),
                1: FlexColumnWidth(1.4),
                2: FlexColumnWidth(1.4),
              },
              children: [
                const TableRow(
                  children: [
                    Text('Tier'),
                    Text('Non-trap\npickups', textAlign: TextAlign.right),
                    Text('All spawns\nwith traps', textAlign: TextAlign.right),
                  ],
                ),
                for (final tier in PowerUpRarity.values)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(tier.label),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${(odds!.nonTrap[tier]! * 100).toStringAsFixed(1)}%',
                          key: ValueKey('rarity-odds-${tier.name}-nontrap'),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${(odds!.allSpawns[tier]! * 100).toStringAsFixed(1)}%',
                          key: ValueKey('rarity-odds-${tier.name}-all'),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                TableRow(
                  children: [
                    const Text('Traps'),
                    const Text('-', textAlign: TextAlign.right),
                    Text(
                      '${(odds!.traps * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Empty field preview after traps start (${trapStartSeconds.toStringAsFixed(0)}s). '
              'Before then, traps have 0% and all spawns follow the non-trap column.',
            ),
          ],
        ],
      ),
    ),
  );
}
