import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'garage_theme.dart';

/// Native input stays independent of the artwork's state listener.
class GarageActionButton extends StatefulWidget {
  const GarageActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.height,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final double height;
  @override
  State<GarageActionButton> createState() => _GarageActionButtonState();
}

class _GarageActionButtonState extends State<GarageActionButton> {
  final _states = WidgetStatesController();
  @override
  void dispose() {
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: math.max(
      widget.height,
      44 * MediaQuery.textScalerOf(context).scale(1),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<Set<WidgetState>>(
          valueListenable: _states,
          builder: (context, states, child) {
            final state = widget.onPressed == null
                ? 'disabled'
                : states.contains(WidgetState.pressed)
                ? 'pressed'
                : 'normal';
            return Image.asset(
              'assets/ui/skins/battle-garage/skin-primary-$state.png',
              centerSlice: const Rect.fromLTWH(24, 24, 208, 16),
              fit: BoxFit.fill,
              errorBuilder: (_, error, stack) {
                debugPrint('UI skin artwork failed: $error');
                return ColoredBox(
                  color: widget.onPressed == null
                      ? GarageTheme.raised
                      : GarageTheme.gold,
                );
              },
            );
          },
        ),
        FilledButton(
          statesController: _states,
          onPressed: widget.onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? GarageTheme.muted
                  : GarageTheme.ink,
            ),
            shape: WidgetStateProperty.resolveWith(
              (states) => TicketBorder(
                side: states.contains(WidgetState.focused)
                    ? const BorderSide(color: GarageTheme.cyan, width: 2)
                    : BorderSide.none,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 26),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
