import 'package:flutter/material.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/power_up_name.dart';
import 'app_settings_scope.dart';

/// An admin can reclassify pickups; traps keep their independent rules.
class PowerUpRarityScreen extends StatefulWidget {
  const PowerUpRarityScreen({super.key, required this.initial});
  final PowerUpConfig initial;
  @override
  State<PowerUpRarityScreen> createState() => _PowerUpRarityScreenState();
}

class _PowerUpRarityScreenState extends State<PowerUpRarityScreen> {
  late PowerUpConfig _config = widget.initial;
  bool? _allowed;
  bool _checking = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checking) { _checking = true; _check(); }
  }
  Future<void> _check() async {
    bool allowed;
    try { allowed = await AppSettingsScope.maybeScope(context)?.adminAuth?.isAdmin() ?? false; }
    catch (_) { allowed = false; }
    if (mounted) setState(() => _allowed = allowed);
  }
  @override
  Widget build(BuildContext context) {
    final kinds = PowerUpKind.values.where((kind) => !kind.isTrap).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return Scaffold(
      appBar: AppBar(title: const Text('Item rarities')),
      body: _allowed != true ? Center(child: _allowed == null
        ? const CircularProgressIndicator() : const Text('Admin access required.'))
        : Column(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text(
            'Set the rarity for every weapon and power-up. Colors and spawn tiers follow these choices. '
            'Traps keep their existing rules. Rarity spawn weights are edited in Power-up numbers.')),
          Expanded(child: ListView.builder(itemCount: kinds.length, itemBuilder: (context, index) {
            final kind = kinds[index];
            final rarity = _config.rarityOf(kind)!;
            return ListTile(
              leading: PowerUpIcon(kind),
              title: PowerUpName(kind, tuning: _config),
              trailing: DropdownButton<PowerUpRarity>(
                key: ValueKey('rarity-${kind.name}'), value: rarity,
                items: [for (final tier in PowerUpRarity.values)
                  DropdownMenuItem(value: tier, child: Container(
                    color: const Color(0xFF17171D), padding: const EdgeInsets.all(4),
                    child: Text(tier.label, style: TextStyle(color: tier.color))))],
                onChanged: (value) { if (value != null) setState(() => _config = _config.withRarity(kind, value)); },
              ),
            );
          })),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(context, _config), child: const Text('Save rarities for everyone'),
            )),
          )),
        ]),
    );
  }
}
