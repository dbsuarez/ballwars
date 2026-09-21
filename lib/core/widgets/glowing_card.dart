import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlowingCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;

  const GlowingCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.russiaGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withOpacity(0.7), width: 1.5),
        boxShadow: [
          BoxShadow(color: glowColor.withOpacity(0.35), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: child,
    );
  }
}
