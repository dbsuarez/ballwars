import 'package:flutter/material.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../arena_simulation/presentation/power_up_sprites.dart';
import '../../arena_simulation/presentation/power_up_name.dart';
import '../../skills/domain/skill_library.dart';
import 'app_settings_scope.dart';

/// What [PowerUpRarityScreen] saves: built-in tiers in [tuning] (`tier.<kind>`), custom skills' own
/// tiers in [library].
class PowerUpRarityResult {
  const PowerUpRarityResult({required this.tuning, required this.library});
  final PowerUpConfig tuning;
  final SkillLibrary library;
}

/// An admin can reclassify pickups and custom skills; traps keep their independent rules.
class PowerUpRarityScreen extends StatefulWidget {
  const PowerUpRarityScreen({super.key, required this.initial, this.skills = SkillLibrary.defaults});
  final PowerUpConfig initial;

  /// The skill library whose custom skills are listed with their own tiers.
  final SkillLibrary skills;
  @override
  State<PowerUpRarityScreen> createState() => _PowerUpRarityScreenState();
}

class _PowerUpRarityScreenState extends State<PowerUpRarityScreen> {
  late PowerUpConfig _config = widget.initial;
  late SkillLibrary _skills = widget.skills;
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

  Widget _tierPicker(Key key, PowerUpRarity value, ValueChanged<PowerUpRarity> onChanged) =>
      DropdownButton<PowerUpRarity>(
        key: key, value: value,
        items: [for (final tier in PowerUpRarity.values)
          DropdownMenuItem(value: tier, child: Container(
            color: const Color(0xFF17171D), padding: const EdgeInsets.all(4),
            child: Text(tier.label, style: TextStyle(color: tier.color))))],
        onChanged: (value) { if (value != null) onChanged(value); },
      );

  @override
  Widget build(BuildContext context) {
    final kinds = PowerUpKind.values.where((kind) => !kind.isTrap).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    final custom = _skills.custom.where((skill) => !skill.baseKind.isTrap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final rows = <Widget>[
      for (final kind in kinds)
        ListTile(
          leading: PowerUpIcon(kind),
          title: PowerUpName(kind, tuning: _config),
          trailing: _tierPicker(ValueKey('rarity-${kind.name}'), _config.rarityOf(kind)!,
              (value) => setState(() => _config = _config.withRarity(kind, value))),
        ),
      if (custom.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Custom skills', style: Theme.of(context).textTheme.titleMedium),
        ),
      for (final skill in custom)
        ListTile(
          leading: PowerUpIcon(skill.displayKind, tint: skill.spriteTint, spriteId: skill.iconSpriteId),
          title: Align(
            alignment: Alignment.centerLeft,
            child: PowerUpName(
              skill.baseKind,
              key: ValueKey('rarity-name-${skill.id}'),
              tuning: _config,
              label: skill.name,
              rarity: SkillLibrary.rarityOf(skill, _config),
            ),
          ),
          subtitle: Text('Custom skill based on ${skill.baseKind.label}'),
          trailing: _tierPicker(ValueKey('rarity-${skill.id}'), SkillLibrary.rarityOf(skill, _config)!,
              (value) => setState(() => _skills = _skills.withDefinition(
                  SkillLibrary.withOwnRarity(skill, value, _config), _config))),
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Item rarities')),
      body: _allowed != true ? Center(child: _allowed == null
        ? const CircularProgressIndicator() : const Text('Admin access required.'))
        : Column(children: [
          const Padding(padding: EdgeInsets.all(16), child: Text(
            'Set the rarity for every weapon and power-up, and for each custom skill on its own. '
            'Colors and spawn tiers follow these choices. '
            'Traps keep their existing rules. Rarity spawn weights are edited in Power-up numbers.')),
          Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (context, index) => rows[index])),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(12),
            child: SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(context, PowerUpRarityResult(tuning: _config, library: _skills)),
              child: const Text('Save rarities for everyone'),
            )),
          )),
        ]),
    );
  }
}
