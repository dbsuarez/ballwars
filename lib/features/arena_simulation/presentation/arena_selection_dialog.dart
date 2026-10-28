import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../settings/domain/app_settings.dart';
import 'arena_preview.dart';

Future<ArenaDecoration?> showArenaSelectionDialog(
  BuildContext context, {
  required ArenaDecoration selected,
}) => showDialog<ArenaDecoration>(
  context: context,
  builder: (_) => ArenaSelectionDialog(selected: selected),
);

/// One centered, scrollable arena chooser for players, admin settings and tests.
class ArenaSelectionDialog extends StatelessWidget {
  const ArenaSelectionDialog({super.key, required this.selected});
  final ArenaDecoration selected;

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('arena-selection-dialog'),
    constraints: const BoxConstraints(maxWidth: 440),
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: const Text('Choose arena'),
    content: SizedBox(
      width: 400,
      height: math.min(460, MediaQuery.sizeOf(context).height * .57),
      child: LayoutBuilder(
        builder: (context, bounds) => GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: bounds.maxWidth >= 260 ? 2 : 1,
            mainAxisExtent:
                144 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: ArenaDecoration.values.length,
          itemBuilder: (context, index) {
            final arena = ArenaDecoration.values[index];
            final active = arena == selected;
            final colors = Theme.of(context).colorScheme;
            return Semantics(
              selected: active,
              button: true,
              label: '${arena.label}, ${arena.hazardCaption}',
              child: Material(
                color: active
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: active ? colors.primary : colors.outlineVariant,
                    width: active ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('arena-option-${arena.name}'),
                  onTap: () => Navigator.pop(context, arena),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              FittedBox(
                                child: ArenaPreview(
                                  decoration: arena,
                                  size: 80,
                                ),
                              ),
                              if (active)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: colors.onPrimaryContainer,
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          arena.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: active
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          arena.hazardCaption,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: active
                                ? colors.onPrimaryContainer
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}
