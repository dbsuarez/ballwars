import 'package:flutter/material.dart';

import 'simulation_ball.dart';

enum CalloutStyle { normal, rare, epic, special }

enum CalloutBubble { shout, speech, thought, radio }

class FloatingText {
  static const double defaultLifespan = 1.2;

  Offset position;
  double age;

  /// Can grow while it shows (a volley's damage adds up in one label).
  String text;
  final Color color;
  final bool callout;
  final CalloutStyle calloutStyle;
  final CalloutBubble calloutBubble;
  final SimulationBall? attachedTo;
  final double lifespan;

  FloatingText({
    required this.position,
    required this.text,
    required this.color,
    this.callout = false,
    this.calloutStyle = CalloutStyle.normal,
    this.calloutBubble = CalloutBubble.shout,
    this.attachedTo,
    this.lifespan = defaultLifespan,
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
    SimulationBall? attachedTo,
    double lifespan = FloatingText.defaultLifespan,
  }) {
    final item = FloatingText(
      position: position,
      text: text,
      color: color,
      callout: callout,
      calloutStyle: calloutStyle,
      calloutBubble: calloutBubble,
      attachedTo: attachedTo,
      lifespan: lifespan,
    );
    _items.add(item);
    return item;
  }

  void update(double dt) {
    for (final item in _items) {
      item.age += dt;
      final attached = item.attachedTo;
      item.position = attached == null
          ? item.position.translate(0, -20 * dt)
          : attached.position - Offset(0, attached.radius + 18 + item.age * 20);
    }
    _items.removeWhere((item) => item.isExpired);
  }
}
