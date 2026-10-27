import 'package:flutter/material.dart';

Future<Color?> showColorPicker(
  BuildContext context, {
  required Color initialColor,
  String title = 'Choose color',
}) {
  var selected = HSVColor.fromColor(initialColor);
  return showDialog<Color>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected.toColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in const [
                      Colors.red,
                      Colors.orange,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.pink,
                      Colors.white,
                      Colors.grey,
                      Colors.black,
                    ])
                      Semantics(
                        label: 'Color swatch',
                        button: true,
                        child: InkWell(
                          onTap: () => refresh(
                            () => selected = HSVColor.fromColor(color),
                          ),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Hue'),
                Slider(
                  value: selected.hue,
                  max: 360,
                  activeColor: selected.toColor(),
                  onChanged: (v) =>
                      refresh(() => selected = selected.withHue(v)),
                ),
                const Text('Saturation'),
                Slider(
                  value: selected.saturation,
                  onChanged: (v) =>
                      refresh(() => selected = selected.withSaturation(v)),
                ),
                const Text('Brightness'),
                Slider(
                  value: selected.value,
                  onChanged: (v) =>
                      refresh(() => selected = selected.withValue(v)),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected.toColor()),
            child: const Text('Use color'),
          ),
        ],
      ),
    ),
  );
}
