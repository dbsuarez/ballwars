import 'package:flutter/material.dart';
import '../offline/device_prefs.dart';
import 'sprite_registry.dart';

enum EffectDensity {
  low('Low', 64, 250),
  balanced('Balanced', 192, 650),
  full('Full', 512, 2000);

  const EffectDensity(this.label, this.effectLimit, this.particleLimit);
  final String label;
  final int effectLimit, particleLimit;
}

class VisualQuality {
  static final density = ValueNotifier(EffectDensity.balanced);
  static Future<void>? _loading;
  static Future<void> load() => _loading ??= _load();
  static Future<void> _load() async {
    final name = await DevicePrefs.read('visual-density');
    density.value =
        EffectDensity.values.where((v) => v.name == name).firstOrNull ??
        EffectDensity.balanced;
    final mb = int.tryParse(await DevicePrefs.read('sprite-cache-mb') ?? '');
    if ({64, 128, 256}.contains(mb)) {
      SpriteRegistry.cacheBudgetBytes = mb! * 1024 * 1024;
    }
  }
}

/// Per-device choices: they never change skill numbers, physics or replay rules.
class VisualQualityControl extends StatefulWidget {
  const VisualQualityControl({super.key});
  @override
  State<VisualQualityControl> createState() => _VisualQualityControlState();
}

class _VisualQualityControlState extends State<VisualQualityControl> {
  @override
  void initState() {
    super.initState();
    VisualQuality.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<EffectDensity>(
    valueListenable: VisualQuality.density,
    builder: (_, density, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Effect detail')),
            Expanded(
              child: DropdownButton<EffectDensity>(
                isExpanded: true,
                value: density,
                items: [
                  for (final d in EffectDensity.values)
                    DropdownMenuItem(value: d, child: Text(d.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  VisualQuality.density.value = v;
                  DevicePrefs.write('visual-density', v.name);
                },
              ),
            ),
          ],
        ),
        const Text(
          'Fewer cosmetic particles and flashes on slower devices. Attacks, traps and damage stay the same.',
          style: TextStyle(fontSize: 12),
        ),
        Row(
          children: [
            const Expanded(child: Text('Artwork cache')),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: SpriteRegistry.cacheBudgetBytes ~/ 1048576,
                items: [
                  for (final mb in [64, 128, 256])
                    DropdownMenuItem(value: mb, child: Text('$mb MB')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    SpriteRegistry.cacheBudgetBytes = v * 1048576;
                    SpriteRegistry.trimCache();
                  });
                  DevicePrefs.write('sprite-cache-mb', v);
                },
              ),
            ),
          ],
        ),
        Text(
          'Decoded artwork: ${(SpriteRegistry.decodedBytes / 1048576).toStringAsFixed(1)} MB / in use: ${(SpriteRegistry.pinnedBytes / 1048576).toStringAsFixed(1)} MB',
          style: const TextStyle(fontSize: 12),
        ),
        const Text(
          'Unused artwork is evicted first. A match keeps its required frames even if they exceed the cache target.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
