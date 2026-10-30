import 'package:flutter/material.dart';

/// Adds accessible steppers without replacing manual entry or its validation.
InputDecoration numberStepperDecoration({
  required TextEditingController controller,
  required InputDecoration decoration,
  required String label,
  required VoidCallback onChanged,
  double step = .1,
  double? min,
  double? max,
  bool integer = false,
  bool enabled = true,
  String? id,
  Key? increaseKey,
  Key? decreaseKey,
}) {
  Widget button(bool increase) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, editing, _) {
      final value = double.tryParse(editing.text);
      final valid = value != null && value.isFinite;
      final available =
          !valid ||
          (increase ? max == null || value < max : min == null || value > min);
      return IconButton(
        key:
            (increase ? increaseKey : decreaseKey) ??
            (id == null
                ? null
                : ValueKey('$id-${increase ? 'increase' : 'decrease'}')),
        tooltip: '${increase ? 'Increase' : 'Decrease'} $label',
        padding: EdgeInsets.zero,
        onPressed: enabled && available
            ? () {
                final base = valid ? value : (min ?? 0);
                final next = (base + (increase ? step : -step)).clamp(
                  min ?? -double.maxFinite,
                  max ?? double.maxFinite,
                );
                final text = integer
                    ? next.round().toString()
                    : double.parse(next.toStringAsFixed(4)).toString();
                controller.value = TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length),
                );
                onChanged();
              }
            : null,
        icon: Icon(increase ? Icons.add : Icons.remove, size: 18),
      );
    },
  );
  return decoration.copyWith(
    prefixIcon: button(false),
    suffixIcon: button(true),
    prefixIconConstraints: const BoxConstraints.tightFor(width: 32, height: 44),
    suffixIconConstraints: const BoxConstraints.tightFor(width: 32, height: 44),
  );
}
