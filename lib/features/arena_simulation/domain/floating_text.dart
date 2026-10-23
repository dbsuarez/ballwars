import 'package:flutter/material.dart';

class FloatingText {
  static const double lifespan = 1.2;

  Offset position;
  double age;
  /// Can grow while it shows (a volley's damage adds up in one label).
  String text;
  final Color color;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.age = 0.0,
  });

  bool get isExpired => age >= lifespan;

  double get opacity => (1.0 - (age / lifespan)).clamp(0.0, 1.0);
}

class FloatingTextManager {
  final List<FloatingText> _items = [];

  List<FloatingText> get items => List.unmodifiable(_items);

  FloatingText spawn(Offset position, String text, Color color) {
    final item = FloatingText(position: position, text: text, color: color);
    _items.add(item);
    return item;
  }

  void update(double dt) {
    for (final item in _items) {
      item.age += dt;
      item.position = item.position.translate(0, -20 * dt);
    }
    _items.removeWhere((item) => item.isExpired);
  }
}
