import 'skill_library.dart';

/// Opt-in authoring helpers for composed skills. These only change delivery and
/// targeting controls; damage, effect steps, artwork and identity are untouched.
enum SkillBehaviorPreset {
  aimedProjectile('Aimed projectile', 'Fire a single shot in the chosen direction'),
  seekingProjectile('Seeking projectile', 'Fire a shot that homes toward the nearest opponent'),
  returningThrow('Returning throw', 'Throw a weapon that returns to its origin'),
  areaBurst('Area burst', 'Activate an effect in an arena area'),
  reactiveShield('Reactive self effect', 'Activate a self-targeted effect when damage is taken'),
  eliminationPulse('Elimination pulse', 'Activate an area effect after an elimination'),
  periodicAura('Periodic aura', 'Activate a self-centered aura on a timer'),
  piercingBeam('Directional beam', 'Fire a directional beam instead of a projectile'),
  opponentSweep('All-opponent effect', 'Apply an instant effect to all opponents'),
  hybridBladeShot('Hybrid blade and shot', 'Ranged projectile with a configurable melee reach'),
  hybridReturningBlade('Hybrid returning blade', 'Thrown returning weapon with melee reach'),
  shadowCloneVolley('Shadow clone volley', 'Composed multi-shot volley targeting the nearest opponent'),
  omegaTendrilSweep('Omega tendril sweep', 'Composed all-opponent area effect on pickup');

  const SkillBehaviorPreset(this.label, this.description);
  final String label;
  final String description;
}

class SkillBehaviorPresetValues {
  const SkillBehaviorPresetValues({
    required this.trigger,
    required this.targeting,
    required this.delivery,
    required this.attackDelivery,
    required this.homing,
    required this.returnsToOrigin,
    required this.projectileCount,
    required this.areaRadiusPercent,
    this.triggerIntervalSeconds,
    this.cooldownSeconds,
  });

  final SkillTrigger trigger;
  final SkillTargeting targeting;
  final SkillDelivery delivery;
  final SkillAttackDelivery? attackDelivery;
  final bool homing;
  final bool returnsToOrigin;
  final int projectileCount;
  final double? areaRadiusPercent;
  final double? triggerIntervalSeconds;
  final double? cooldownSeconds;
}

class SkillBehaviorPresets {
  const SkillBehaviorPresets._();

  static SkillBehaviorPresetValues values(SkillBehaviorPreset preset) =>
      switch (preset) {
        SkillBehaviorPreset.hybridBladeShot => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.fireProjectile,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.hybridReturningBlade => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.throwWeapon,
          homing: false,
          returnsToOrigin: true,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.shadowCloneVolley => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.nearestOpponent,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.fireProjectile,
          homing: true,
          returnsToOrigin: false,
          projectileCount: 3,
          areaRadiusPercent: null,
          cooldownSeconds: 4,
        ),
        SkillBehaviorPreset.omegaTendrilSweep => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.area,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: 25,
          cooldownSeconds: 3,
        ),
        SkillBehaviorPreset.aimedProjectile => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.fireProjectile,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.seekingProjectile => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.nearestOpponent,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.fireProjectile,
          homing: true,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.returningThrow => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.projectile,
          attackDelivery: SkillAttackDelivery.throwWeapon,
          homing: false,
          returnsToOrigin: true,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.reactiveShield => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.damageTaken,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.instant,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
          cooldownSeconds: 3,
        ),
        SkillBehaviorPreset.eliminationPulse => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.elimination,
          targeting: SkillTargeting.arenaLocation,
          delivery: SkillDelivery.area,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: 20,
          cooldownSeconds: 2,
        ),
        SkillBehaviorPreset.periodicAura => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.timer,
          targeting: SkillTargeting.self,
          delivery: SkillDelivery.aura,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: 15,
          triggerIntervalSeconds: 4,
        ),
        SkillBehaviorPreset.piercingBeam => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.aimedFire,
          targeting: SkillTargeting.chosenDirection,
          delivery: SkillDelivery.beam,
          attackDelivery: SkillAttackDelivery.beam,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.opponentSweep => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.pickup,
          targeting: SkillTargeting.allOpponents,
          delivery: SkillDelivery.instant,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: null,
        ),
        SkillBehaviorPreset.areaBurst => const SkillBehaviorPresetValues(
          trigger: SkillTrigger.timer,
          targeting: SkillTargeting.arenaLocation,
          delivery: SkillDelivery.area,
          attackDelivery: null,
          homing: false,
          returnsToOrigin: false,
          projectileCount: 1,
          areaRadiusPercent: 20,
        ),
      };

  static SkillDefinition apply(SkillDefinition skill, SkillBehaviorPreset preset) {
    final config = values(preset);
    return skill.copyWith(
      trigger: config.trigger,
      targeting: config.targeting,
      delivery: config.delivery,
      attackDelivery: config.attackDelivery,
      weaponClass: switch (preset) {
        SkillBehaviorPreset.hybridBladeShot ||
        SkillBehaviorPreset.hybridReturningBlade => SkillWeaponClass.hybrid,
        _ => skill.weaponClass,
      },
      meleeReach: switch (preset) {
        SkillBehaviorPreset.hybridBladeShot ||
        SkillBehaviorPreset.hybridReturningBlade =>
          skill.meleeReach > 0 ? skill.meleeReach : 1.2,
        _ => skill.meleeReach,
      },
      homing: config.homing,
      returnsToOrigin: config.returnsToOrigin,
      projectileCount: config.projectileCount,
      areaRadiusRatio: config.areaRadiusPercent == null
          ? null
          : config.areaRadiusPercent! / 100,
      triggerIntervalSeconds: config.triggerIntervalSeconds ?? skill.triggerIntervalSeconds,
      cooldownSeconds: config.cooldownSeconds ?? skill.cooldownSeconds,
    );
  }
}
