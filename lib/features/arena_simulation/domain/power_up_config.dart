import 'dart:convert';

import 'power_up.dart';

/// How a [TuningField] is shown and stored: times in seconds (the simulation runs 60 steps a second),
/// shares in percent, plain counts or ratios.
enum TuningUnit { count, seconds, percent, ratio }

/// One number the admin can change in Settings: its id (the key in links and in Supabase), label, group,
/// default (today's [PowerUpTuning] value) and allowed range, in [unit].
class TuningField {
  final String id;
  final String label;
  final String group;
  final num defaultValue;
  final num min;
  final num max;
  final TuningUnit unit;

  /// Whole numbers only (counts, damage in lines).
  final bool integer;

  const TuningField(
    this.id,
    this.label,
    this.group,
    this.defaultValue, {
    required this.min,
    required this.max,
    this.unit = TuningUnit.count,
    this.integer = false,
  });

  /// [value] clamped into range (and rounded for [integer] fields).
  num clamp(num value) {
    final clamped = value.clamp(min, max);
    return integer ? clamped.round() : clamped.toDouble();
  }
}

/// The power-up numbers of a match: [PowerUpTuning]'s defaults, with any of the [fields] the admin changed
/// in Settings. It is part of the match (it changes how it plays out), so it travels in replay links as
/// only the changed values ([encode] / [decode]).
class PowerUpConfig {
  /// Changed values by field id, in the field's [TuningUnit]; fields not listed use their default.
  final Map<String, num> overrides;

  const PowerUpConfig([this.overrides = const {}]);

  /// Every value at its default.
  static const PowerUpConfig defaults = PowerUpConfig();

  static const String _spawning = 'Spawning';
  static const String _guns = 'Guns';
  static const String _arsenal = 'Damage - Arsenal (life)';
  static const String _allOut = 'Damage - All-Out (lines)';
  static const String _effects = 'Effects';
  static const String _arenaTraps = 'Arena traps';
  static const String _skills = 'Skill Management';

  /// The kinds that do damage, with their own damage fields.
  static const List<PowerUpKind> damageKinds = [
    PowerUpKind.pistol,
    PowerUpKind.shotgun,
    PowerUpKind.gatling,
    PowerUpKind.knife,
    PowerUpKind.sword,
    PowerUpKind.mine,
    PowerUpKind.grenade,
    PowerUpKind.hook,
    PowerUpKind.ricochetDisc,
    PowerUpKind.orbitingFlail,
    PowerUpKind.threadHarpoon,
    PowerUpKind.prismLaser,
    PowerUpKind.swapCannon,
    PowerUpKind.phaseMine,
    PowerUpKind.spikeWall,
    PowerUpKind.bow,
    PowerUpKind.molotov,
    PowerUpKind.rocketLauncher,
    PowerUpKind.omegaTendrils,
    PowerUpKind.boomerang,
    PowerUpKind.fireWall,
    PowerUpKind.poisonSwamp,
    PowerUpKind.waterGun,
    PowerUpKind.lightningStrikes,
    PowerUpKind.earthquake,
    PowerUpKind.tornado,
    PowerUpKind.energyWave,
    PowerUpKind.flamethrower,
    PowerUpKind.busterSword,
    PowerUpKind.ragingDemon,
    PowerUpKind.shadowClone,
  ];

  /// Everything the admin can change, in the order Settings shows it.
  static final List<TuningField> fields = [
    for (final kind in PowerUpKind.values.where((kind) => !kind.isTrap))
      TuningField(
        'tier.${kind.name}',
        kind.label,
        'Rarity assignments',
        kind.rarity!.index,
        min: 0,
        max: 3,
        integer: true,
      ),
    for (final entry in const {
      'normal': 50,
      'rare': 45,
      'epic': 40,
      'special': 35,
    }.entries)
      TuningField(
        'rarity.${entry.key}',
        '${entry.key[0].toUpperCase()}${entry.key.substring(1)} spawn weight',
        'Rarity spawn weights',
        entry.value,
        min: 0,
        max: 100,
        unit: TuningUnit.percent,
      ),
    TuningField(
      'firstSpawn',
      'First power-up after',
      _spawning,
      PowerUpTuning.firstSpawnSteps / 60,
      min: 0,
      max: 30,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'spawnEvery',
      'Then one every (2 balls)',
      _spawning,
      PowerUpTuning.spawnIntervalSteps / 60,
      min: 0.5,
      max: 60,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'trapStart',
      'Traps start after',
      _spawning,
      PowerUpTuning.trapStartSteps / 60,
      min: 0,
      max: 600,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'arenaTrapsEnabled',
      'Arena traps (1 on, 0 off)',
      _arenaTraps,
      1,
      min: 0,
      max: 1,
      integer: true,
    ),
    TuningField(
      'arenaTrapInterval',
      'Spawn interval',
      _arenaTraps,
      15,
      min: 2,
      max: 120,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'arenaTrapDuration',
      'Active duration',
      _arenaTraps,
      10,
      min: 1,
      max: 60,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'gravityWellForce',
      'Gravity Well force',
      _arenaTraps,
      0.012,
      min: 0,
      max: 0.1,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'quicksandSlowdown',
      'Quicksand slowdown',
      _arenaTraps,
      7,
      min: 0,
      max: 50,
      unit: TuningUnit.percent,
    ),
    TuningField(
      'quicksandDamage',
      'Quicksand damage / DoT',
      _arenaTraps,
      2,
      min: 0,
      max: 50,
    ),
    TuningField(
      'quicksandLines',
      'Quicksand lines / DoT',
      _arenaTraps,
      1,
      min: 0,
      max: 20,
      integer: true,
    ),
    TuningField(
      'vineSnareDuration',
      'Vine Snare hold',
      _arenaTraps,
      2,
      min: 0.25,
      max: 10,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'laserGateDamage',
      'Laser Gate damage',
      _arenaTraps,
      8,
      min: 0,
      max: 100,
    ),
    TuningField(
      'laserGateLines',
      'Laser Gate lines',
      _arenaTraps,
      3,
      min: 0,
      max: 30,
      integer: true,
    ),
    TuningField(
      'fieldSize',
      'Power-up size (x ball)',
      _spawning,
      PowerUpTuning.fieldRadiusRatio,
      min: 0.3,
      max: 1.5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'aim',
      'Aim time',
      _guns,
      PowerUpTuning.aimSteps / 60,
      min: 0,
      max: 5,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'bulletSpeed',
      'Bullet speed (arena radii/s)',
      _guns,
      PowerUpTuning.bulletSpeedRatio,
      min: 0.2,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'grenadeSpeed',
      'Grenade speed (arena radii/s)',
      _guns,
      PowerUpTuning.grenadeSpeedRatio,
      min: 0.2,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'pellets',
      'Shotgun pellets',
      _guns,
      PowerUpTuning.shotgunPellets,
      min: 2,
      max: 30,
      integer: true,
    ),
    TuningField(
      'rounds',
      'Gatling rounds',
      _guns,
      PowerUpTuning.gatlingRounds,
      min: 1,
      max: 50,
      integer: true,
    ),
    TuningField(
      'arrows',
      'Bow arrows',
      _guns,
      PowerUpTuning.bowArrows,
      min: 1,
      max: 50,
      integer: true,
    ),
    TuningField(
      'ragingDemonHits',
      'Raging Demon hits',
      _guns,
      24,
      min: 1,
      max: 60,
      integer: true,
    ),
    TuningField(
      'shadowCloneCount',
      'Shadow clones',
      _guns,
      3,
      min: 1,
      max: 6,
      integer: true,
    ),
    TuningField(
      'unarmedCollision',
      'Unequipped ball collision damage',
      _arsenal,
      PowerUpTuning.arenaCollisionDamage,
      min: 0,
      max: 200,
    ),
    TuningField(
      'frozenDamageMultiplier',
      'Damage received while frozen',
      _arsenal,
      1.5,
      min: 1,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'frozenCollisionDamage',
      'Extra damage when colliding while frozen',
      _arsenal,
      5,
      min: 0,
      max: 200,
    ),
    for (final kind in damageKinds)
      TuningField(
        'dmg.${kind.name}',
        '${kind.label}${_each(kind)}',
        _arsenal,
        PowerUpTuning.arenaDamage[kind] ?? 0,
        min: 0,
        max: 200,
      ),
    TuningField(
      'bash',
      'Shield bash',
      _arsenal,
      PowerUpTuning.arenaShieldBash,
      min: 0,
      max: 200,
    ),
    TuningField(
      'block',
      'Shield blocks',
      _arsenal,
      PowerUpTuning.shieldBlock * 100,
      min: 0,
      max: 100,
      unit: TuningUnit.percent,
    ),
    TuningField(
      'heal',
      'Apple heals',
      _arsenal,
      PowerUpTuning.arenaAppleHeal,
      min: 0,
      max: 200,
    ),
    TuningField(
      'maxLife',
      'Most life (apples)',
      _arsenal,
      PowerUpTuning.arenaMaxLife,
      min: 100,
      max: 200,
    ),
    for (final kind in damageKinds)
      TuningField(
        'lines.${kind.name}',
        '${kind.label}${_each(kind)}',
        _allOut,
        PowerUpTuning.allOutThreads[kind] ?? 0,
        min: 0,
        max: 180,
        integer: true,
      ),
    TuningField('dmg.speed', 'Speed collision', _skills, 0, min: 0, max: 200),
    TuningField(
      'lines.speed',
      'Speed collision',
      _skills,
      0,
      min: 0,
      max: 180,
      integer: true,
    ),
    TuningField(
      'lines.bash',
      'Shield bash',
      _allOut,
      PowerUpTuning.allOutShieldBash,
      min: 0,
      max: 180,
      integer: true,
    ),
    TuningField(
      'keep',
      'Shield keeps lines lost at',
      _allOut,
      PowerUpTuning.allOutShieldKeep * 100,
      min: 0,
      max: 100,
      unit: TuningUnit.percent,
    ),
    TuningField(
      'appleLines',
      'Apple adds lines',
      _allOut,
      PowerUpTuning.allOutAppleSlots,
      min: 0,
      max: 180,
      integer: true,
    ),
    TuningField(
      'speed',
      'Speed boost lasts',
      _effects,
      PowerUpTuning.speedSteps / 60,
      min: 0.5,
      max: 20,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'freeze',
      'Freeze lasts',
      _effects,
      PowerUpTuning.freezeSteps / 60,
      min: 0.5,
      max: 20,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'ghost',
      'Ghost lasts',
      _effects,
      PowerUpTuning.ghostSteps / 60,
      min: 0.5,
      max: 20,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'blast',
      'Blast radius (x arena radius)',
      _effects,
      PowerUpTuning.blastRadiusRatio,
      min: 0.05,
      max: 1,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'speedFactor',
      'Speed multiplier',
      _skills,
      PowerUpTuning.speedFactor,
      min: 1,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'maximumPowerDuration',
      'Maximum Power duration',
      _skills,
      3,
      min: 0.1,
      max: 30,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'maximumPowerAmount',
      'Maximum Power multiplier',
      _skills,
      1.5,
      min: 1,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'repulsorDuration',
      'Repulsor duration',
      _skills,
      3,
      min: 0.1,
      max: 30,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'repulsorForce',
      'Repulsor force',
      _skills,
      1.4,
      min: 0,
      max: 5,
      unit: TuningUnit.ratio,
    ),
    TuningField(
      'timeBubbleDuration',
      'Time Bubble duration',
      _skills,
      3,
      min: 0.1,
      max: 30,
      unit: TuningUnit.seconds,
    ),
    TuningField(
      'timeBubbleRange',
      'Time Bubble range (x ball)',
      _skills,
      3,
      min: 1,
      max: 12,
      unit: TuningUnit.ratio,
    ),
    for (final kind in PowerUpKind.values.where((kind) => kind.isGun))
      TuningField(
        'skillSpeed.${kind.name}',
        '${kind.label} projectile speed',
        _skills,
        PowerUpTuning.bulletSpeedRatio,
        min: 0.1,
        max: 10,
        unit: TuningUnit.ratio,
      ),
    TuningField(
      'skillSpread.shotgun',
      'Shotgun spread',
      _skills,
      PowerUpTuning.shotgunSpread,
      min: 0,
      max: 3.141592653589793,
      unit: TuningUnit.ratio,
    ),
    for (final kind in const [PowerUpKind.ricochetDisc, PowerUpKind.prismLaser])
      TuningField(
        'skillBounces.${kind.name}',
        '${kind.label} bounces',
        _skills,
        1,
        min: 0,
        max: 20,
        integer: true,
      ),
    for (final kind in const [
      PowerUpKind.energyWave,
      PowerUpKind.omegaTendrils,
    ])
      TuningField(
        'skillKnockback.${kind.name}',
        '${kind.label} knockback',
        _skills,
        1,
        min: 0,
        max: 10,
        unit: TuningUnit.ratio,
      ),
  ];

  static String _each(PowerUpKind kind) => kind == PowerUpKind.shotgun
      ? ' (per pellet)'
      : kind == PowerUpKind.gatling
      ? ' (per round)'
      : kind == PowerUpKind.molotov ||
            kind == PowerUpKind.fireWall ||
            kind == PowerUpKind.poisonSwamp ||
            kind == PowerUpKind.tornado ||
            kind == PowerUpKind.flamethrower
      ? ' (DoT)'
      : '';

  static final Map<String, TuningField> _byId = {
    for (final f in fields) f.id: f,
  };

  /// The field with [id], or null.
  static TuningField? field(String id) => _byId[id];

  /// The value of field [id] (its override or its default).
  num value(String id) => overrides[id] ?? _byId[id]!.defaultValue;

  bool get isDefault => overrides.isEmpty;

  int _steps(String id) => (value(id) * 60).round();

  double _share(String id) => value(id) / 100;

  // --- Typed values used by the match ---

  int get firstSpawnSteps => _steps('firstSpawn');
  int get trapStartSteps => _steps('trapStart');
  bool get arenaTrapsEnabled => value('arenaTrapsEnabled') != 0;
  int get arenaTrapIntervalSteps => _steps('arenaTrapInterval');
  int get arenaTrapDurationSteps => _steps('arenaTrapDuration');
  double get gravityWellForce => value('gravityWellForce').toDouble();
  double get quicksandVelocityMultiplier => 1 - _share('quicksandSlowdown');
  double get quicksandDamage => value('quicksandDamage').toDouble();
  int get quicksandLines => value('quicksandLines').toInt();
  int get vineSnareSteps => _steps('vineSnareDuration');
  double get laserGateDamage => value('laserGateDamage').toDouble();
  int get laserGateLines => value('laserGateLines').toInt();

  /// Steps between spawns for [ballCount] balls (more balls, more often), as [PowerUpTuning.spawnInterval].
  int spawnInterval(int ballCount) =>
      (_steps('spawnEvery') * 2 / (ballCount < 2 ? 2 : ballCount))
          .round()
          .clamp(1, 1 << 30);

  PowerUpRarity? rarityOf(PowerUpKind kind) => kind.isTrap
      ? null
      : PowerUpRarity.values[value('tier.${kind.name}').toInt().clamp(0, 3)];

  PowerUpConfig withRarity(PowerUpKind kind, PowerUpRarity rarity) =>
      kind.isTrap ? this : withValue('tier.${kind.name}', rarity.index);

  double rarityWeight(PowerUpRarity rarity) =>
      value('rarity.${rarity.name}').toDouble();

  double get fieldRadiusRatio => value('fieldSize').toDouble();
  int get aimSteps => _steps('aim');
  double get bulletSpeedRatio => value('bulletSpeed').toDouble();
  double get grenadeSpeedRatio => value('grenadeSpeed').toDouble();
  int get shotgunPellets => value('pellets').toInt();
  int get gatlingRounds => value('rounds').toInt();
  int get bowArrows => value('arrows').toInt();
  int get ragingDemonHits => value('ragingDemonHits').toInt();
  int get shadowCloneCount => value('shadowCloneCount').toInt();

  /// Arsenal life lost per hit of [kind] (0 for kinds that do no damage).
  double arenaDamage(PowerUpKind kind) => _byId.containsKey('dmg.${kind.name}')
      ? value('dmg.${kind.name}').toDouble()
      : 0;
  double get unarmedCollisionDamage => value('unarmedCollision').toDouble();
  double get frozenDamageMultiplier =>
      value('frozenDamageMultiplier').toDouble();
  double get frozenCollisionDamage => value('frozenCollisionDamage').toDouble();
  double get arenaShieldBash => value('bash').toDouble();
  double get shieldBlock => _share('block');
  double get arenaAppleHeal => value('heal').toDouble();
  double get arenaMaxLife => value('maxLife').toDouble();

  /// All-Out lines cut per hit of [kind] (0 for kinds that do no damage).
  int allOutThreads(PowerUpKind kind) => _byId.containsKey('lines.${kind.name}')
      ? value('lines.${kind.name}').toInt()
      : 0;
  int get allOutShieldBash => value('lines.bash').toInt();
  double get allOutShieldKeep => _share('keep');
  int get allOutAppleSlots => value('appleLines').toInt();

  int get speedSteps => _steps('speed');
  int get freezeSteps => _steps('freeze');
  int get ghostSteps => _steps('ghost');
  double get blastRadiusRatio => value('blast').toDouble();
  double get speedFactor => value('speedFactor').toDouble();
  int get maximumPowerSteps => _steps('maximumPowerDuration');
  double get maximumPowerAmount => value('maximumPowerAmount').toDouble();
  int get repulsorSteps => _steps('repulsorDuration');
  double get repulsorForce => value('repulsorForce').toDouble();
  int get timeBubbleSteps => _steps('timeBubbleDuration');
  double get timeBubbleRange => value('timeBubbleRange').toDouble();
  double projectileSpeedRatio(PowerUpKind kind) =>
      _byId.containsKey('skillSpeed.${kind.name}')
      ? value('skillSpeed.${kind.name}').toDouble()
      : bulletSpeedRatio;
  double get shotgunSpreadRadians => value('skillSpread.shotgun').toDouble();
  int maxBounces(PowerUpKind kind) =>
      _byId.containsKey('skillBounces.${kind.name}')
      ? value('skillBounces.${kind.name}').toInt()
      : 0;
  double knockback(PowerUpKind kind) =>
      _byId.containsKey('skillKnockback.${kind.name}')
      ? value('skillKnockback.${kind.name}').toDouble()
      : 1;

  // --- Storage ---

  /// A copy with field [id] set to [value] (clamped; back to default when equal to it).
  PowerUpConfig withValue(String id, num value) {
    final f = _byId[id];
    if (f == null) return this;
    final v = f.clamp(value);
    final next = Map<String, num>.of(overrides);
    if (v == f.defaultValue) {
      next.remove(id);
    } else {
      next[id] = v;
    }
    return PowerUpConfig(Map.unmodifiable(next));
  }

  /// The changed values only, as JSON.
  Map<String, num> toJson() => Map.of(overrides);

  /// Lenient: from the admin's saved settings. Unknown keys and non-numbers are skipped, values clamped.
  factory PowerUpConfig.fromJson(Object? json) {
    var config = PowerUpConfig.defaults;
    if (json is! Map) return config;
    for (final entry in json.entries) {
      final value = entry.value;
      if (entry.key is String && value is num && value.isFinite) {
        config = config.withValue(entry.key as String, value);
      }
    }
    return config;
  }

  /// Replay JSON includes changed tuning plus a compact rarity snapshot.
  String? encode() {
    final payload = <String, Object>{...toJson()};
    // Snapshot the current rarity assignments and weights for new replays.
    payload.removeWhere((key, _) => key.startsWith('tier.'));
    payload['_tiers'] = PowerUpKind.values
        .map((kind) => kind.isTrap ? '-' : '${rarityOf(kind)!.index}')
        .join();
    for (final rarity in PowerUpRarity.values) {
      payload['rarity.${rarity.name}'] = rarityWeight(rarity);
    }
    return base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
  }

  /// Strict, for links (they come from anywhere): null when [text] isn't something [encode] could have made
  /// (bad encoding, unknown keys, non-numbers or values out of range).
  static PowerUpConfig? decode(String text) {
    if (text.isEmpty || text.length > 2000) return null;
    try {
      final padded = text.padRight((text.length + 3) ~/ 4 * 4, '=');
      final json = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (json is! Map) return null;
      var config = PowerUpConfig.defaults;
      final tiers = json['_tiers'];
      if (tiers != null) {
        // Shorter lists come from links made before newer kinds existed: those keep their
        // default tier (ReplayLink leaves them out of the pool anyway).
        if (tiers is! String ||
            tiers.isEmpty ||
            tiers.length > PowerUpKind.values.length) {
          return null;
        }
        for (final kind in PowerUpKind.values.take(tiers.length)) {
          final digit = tiers[kind.index];
          if (kind.isTrap) {
            if (digit != '-') return null;
          } else {
            final index = int.tryParse(digit);
            if (index == null || index < 0 || index > 3) return null;
            config = config.withRarity(kind, PowerUpRarity.values[index]);
          }
        }
      }
      for (final entry in json.entries) {
        if (entry.key == '_tiers') continue;
        final f = entry.key is String ? _byId[entry.key] : null;
        final value = entry.value;
        if (f == null ||
            value is! num ||
            !value.isFinite ||
            value < f.min ||
            value > f.max) {
          return null;
        }
        if (f.integer && value != value.roundToDouble()) return null;
        config = config.withValue(f.id, value);
      }
      return config;
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PowerUpConfig &&
      other.overrides.length == overrides.length &&
      overrides.entries.every((e) => other.overrides[e.key] == e.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    overrides.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
