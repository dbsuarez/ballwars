import 'package:flutter/material.dart';
import '../domain/power_up.dart';
import '../domain/power_up_config.dart';

/// A consistent readable name, including on light arena/app themes.
class PowerUpName extends StatelessWidget {
  const PowerUpName(this.kind, {super.key, this.tuning = PowerUpConfig.defaults, this.style});
  final PowerUpKind kind;
  final PowerUpConfig tuning;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final rarity = tuning.rarityOf(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: rarity == null ? Colors.transparent : const Color(0xFF17171D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(kind.label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: (style ?? DefaultTextStyle.of(context).style).copyWith(color: rarity?.color)),
    );
  }
}
