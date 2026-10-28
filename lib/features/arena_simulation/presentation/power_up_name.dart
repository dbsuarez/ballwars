import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';

/// A consistent readable name, including on light arena/app themes.
///
/// [label] and [rarity] name a skill instead of the bare kind (a custom skill shows its own name and
/// its own tier, `SkillLibrary.rarityOf`); without them the kind's label and its tier in [tuning].
class PowerUpName extends StatelessWidget {
  const PowerUpName(this.kind, {super.key, this.tuning = PowerUpConfig.defaults, this.style, this.label, this.rarity});
  final PowerUpKind kind;
  final PowerUpConfig tuning;
  final TextStyle? style;
  final String? label;
  final PowerUpRarity? rarity;
  @override
  Widget build(BuildContext context) {
    final rarity = this.rarity ?? tuning.rarityOf(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: rarity == null ? Colors.transparent : const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label ?? kind.label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(color: rarity?.color)),
    );
  }
}
