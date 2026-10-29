import '../../arena_simulation/domain/power_up.dart';

/// An explicit pickup pool. Traps remain automatic and are not part of a preset.
class LoadoutPreset {
  LoadoutPreset({
    required this.id,
    required this.name,
    required Iterable<PowerUpKind> kinds,
    Iterable<String> customIds = const [],
    this.description = '',
  }) : kinds = Set.unmodifiable(kinds.where((kind) => !kind.isTrap)),
       customIds = Set.unmodifiable(customIds);

  final String id;
  final String name;
  final String description;
  final Set<PowerUpKind> kinds;
  final Set<String> customIds;

  LoadoutPreset renamed(String name) =>
      LoadoutPreset(id: id, name: name, kinds: kinds, customIds: customIds);

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'kinds': kinds.map((kind) => kind.name).toList(),
    'customIds': customIds.toList(),
  };

  factory LoadoutPreset.fromJson(Map<String, dynamic> json) => LoadoutPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    kinds: PowerUpKind.values.where(
      (kind) => (json['kinds'] as List).contains(kind.name),
    ),
    customIds: (json['customIds'] as List).cast<String>(),
  );

  static const military = {
    PowerUpKind.pistol,
    PowerUpKind.shotgun,
    PowerUpKind.gatling,
    PowerUpKind.knife,
    PowerUpKind.grenade,
    PowerUpKind.molotov,
    PowerUpKind.rocketLauncher,
    PowerUpKind.flamethrower,
    PowerUpKind.sniperRifle,
  };

  static final builtIns = List<LoadoutPreset>.unmodifiable([
    LoadoutPreset(
      id: 'military',
      name: 'Military',
      description:
          'Firearms, explosives, flamethrower and knife. Weapons only.',
      kinds: military,
    ),
    LoadoutPreset(
      id: 'unique',
      name: 'Unique Weapons',
      description:
          'Unusual weapons, magic and sci-fi gear. No military weapons.',
      kinds: PowerUpKind.values.where(
        (k) => k.isWeapon && !military.contains(k),
      ),
    ),
    LoadoutPreset(
      id: 'melee',
      name: 'Close Combat',
      description: 'Knife, sword, shield, orbiting flail and Buster Sword.',
      kinds: {
        PowerUpKind.knife,
        PowerUpKind.sword,
        PowerUpKind.shield,
        PowerUpKind.orbitingFlail,
        PowerUpKind.busterSword,
      },
    ),
    LoadoutPreset(
      id: 'elements',
      name: 'Elemental',
      description: 'Fire, ice, water, lightning, earth and wind.',
      kinds: {
        PowerUpKind.freeze,
        PowerUpKind.fireWall,
        PowerUpKind.molotov,
        PowerUpKind.flamethrower,
        PowerUpKind.waterGun,
        PowerUpKind.lightningStrikes,
        PowerUpKind.earthquake,
        PowerUpKind.tornado,
      },
    ),
    LoadoutPreset(
      id: 'power-ups',
      name: 'Power-ups Only',
      description: 'All built-in power-ups, without weapon pickups.',
      kinds: PowerUpKind.values.where((k) => k.isPowerUp),
    ),
  ]);
}
