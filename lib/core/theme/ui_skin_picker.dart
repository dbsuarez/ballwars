import 'package:flutter/material.dart';
import 'ui_skin.dart';
import 'ui_skin_scope.dart';

class UiSkinPicker extends StatelessWidget {
  const UiSkinPicker({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = UiSkinScope.controllerOf(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UI Skin', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Saved on this device. Arena backgrounds and game settings stay as selected.',
        ),
        const SizedBox(height: 12),
        for (final skin in UiSkin.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              selected: controller.value == skin,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: controller.saving
                      ? null
                      : () => controller.select(skin),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/ui/skins/${skin.id}/preview.png',
                            width: 78,
                            height: 144,
                            fit: BoxFit.cover,
                            cacheWidth: 156,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                skin.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(skin.description),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          controller.value == skin
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          semanticLabel: controller.value == skin
                              ? 'Selected'
                              : 'Choose skin',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (controller.saving) const LinearProgressIndicator(),
        if (controller.error != null)
          Text(
            controller.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}
