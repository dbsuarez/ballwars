/// Physical shape of the outer arena. Independent of match mode.
enum ArenaShape {
  circle('Circle'),
  square('Square');

  final String label;
  const ArenaShape(this.label);

  static ArenaShape? byName(String? value) =>
      values.where((shape) => shape.name == value).firstOrNull;
}

/// Optional solid central wall. The empty space around it remains playable.
enum CenterObstacle {
  none('None'),
  circle('Circle'),
  square('Square');

  final String label;
  const CenterObstacle(this.label);

  static CenterObstacle? byName(String? value) =>
      values.where((item) => item.name == value).firstOrNull;
}
