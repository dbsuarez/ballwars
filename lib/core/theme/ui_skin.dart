enum UiSkin {
  classic(
    'classic-arcade',
    'Classic Arcade',
    'Bright stadium lights and glowing arcade panels.',
  ),
  garage(
    'battle-garage',
    'Battle Garage',
    'Dark workshop panels, cut corners and raised gold buttons.',
  );

  const UiSkin(this.id, this.label, this.description);
  final String id, label, description;
  static UiSkin fromId(String? id) =>
      values.where((skin) => skin.id == id).firstOrNull ?? classic;
}
