enum ArenaDecoration {
  defaultArena('Default'),
  space('Space'),
  desert('Desert'),
  wilderness('Wilderness'),
  neonGrid('Neon Grid'),
  chaotic('Chaotic');

  const ArenaDecoration(this.label);
  final String label;

  /// The hazard this arena adds, as the arena pickers caption it under [label].
  String get hazardCaption => switch (this) {
    ArenaDecoration.defaultArena => 'Spike Wall',
    ArenaDecoration.space => 'Gravity Well',
    ArenaDecoration.desert => 'Quicksand',
    ArenaDecoration.wilderness => 'Vine Snare',
    ArenaDecoration.neonGrid => 'Laser Gate',
    ArenaDecoration.chaotic => 'All arena traps',
  };
}
