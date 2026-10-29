import 'package:flutter/material.dart';

/// Consistent visible marker for retained compatibility controls.
class LegacyTag extends StatelessWidget {
  const LegacyTag({
    super.key,
    this.explanation = 'Older setting retained for compatibility.',
  });
  final String explanation;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: explanation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Legacy',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
