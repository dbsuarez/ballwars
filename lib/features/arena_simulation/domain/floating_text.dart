import 'package:flutter/material.dart';

enum CalloutStyle { normal, rare, epic, special }

enum CalloutBubble { shout, speech, thought, radio }

class FloatingText {
  static const double lifespan = 1.2;

  Offset position;
  double age;

  /// Can grow while it shows (a volley's damage adds up in one label).
  String text;
  final Color color;
  final bool callout;
  final CalloutStyle calloutStyle;
  final CalloutBubble calloutBubble;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.callout = false,
    this.calloutStyle = CalloutStyle.normal,
    this.calloutBubble = CalloutBubble.shout,
    this.age = 0.0,
  });

  bool get isExpired => age >= lifespan;

  double get opacity => (1.0 - (age / lifespan)).clamp(0.0, 1.0);
}

class FloatingTextManager {
  final List<FloatingText> _items = [];

  List<FloatingText> get items => List.unmodifiable(_items);

  FloatingText spawn(
    Offset position,
    String text,
    Color color, {
    bool callout = false,
    CalloutStyle calloutStyle = CalloutStyle.normal,
    CalloutBubble calloutBubble = CalloutBubble.shout,
  }) {
    final item = FloatingText(
      position: position,
      text: text,
      color: color,
      callout: callout,
      calloutStyle: calloutStyle,
      calloutBubble: calloutBubble,
    );
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
