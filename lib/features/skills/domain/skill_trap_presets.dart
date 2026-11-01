import 'skill_library.dart';

/// Authoring presets only. Applying one does not change skill identity, artwork,
/// rarity, damage, or effect steps. The user must explicitly select a preset.
enum SkillTrapPreset {
  timedPulse('Timed pulse', 'Pulses in an area every 5 seconds'),
  contactTrap('Contact trap', 'Triggers when a target collides'),
  persistentHazard('Persistent hazard', 'Repeated area ticks with a short interval');

  const SkillTrapPreset(this.label, this.description);
  final String label;
  final String description;
}

class SkillTrapPresetValues {
  const SkillTrapPresetValues({
    required this.trigger,
    required this.targeting,
    required this.delivery,
    required this.triggerIntervalSeconds,
    required this.tickIntervalSeconds,
    required this.areaRadiusPercent,
    required this.cooldownSeconds,
  });

  final SkillTrigger trigger;
  final SkillTargeting targeting;
  final SkillDelivery delivery;
  final double triggerIntervalSeconds;
  final double tickIntervalSeconds;
  final double areaRadiusPercent;
  final double cooldownSeconds;
}

class SkillTrapPresets {
  const SkillTrapPresets._();

  static SkillTrapPresetValues values(SkillTrapPreset preset) => switch (preset) {
    SkillTrapPreset.timedPulse => const SkillTrapPresetValues(
        trigger: SkillTrigger.timer,
        targeting: SkillTargeting.arenaLocation,
        delivery: SkillDelivery.area,
        triggerIntervalSeconds: 5,
        tickIntervalSeconds: 0.5,
        areaRadiusPercent: 20,
        cooldownSeconds: 0,
      ),
    SkillTrapPreset.contactTrap => const SkillTrapPresetValues(
        trigger: SkillTrigger.collision,
        targeting: SkillTargeting.nearestOpponent,
        delivery: SkillDelivery.area,
        triggerIntervalSeconds: 5,
        tickIntervalSeconds: 0.5,
        areaRadiusPercent: 12,
        cooldownSeconds: 1,
      ),
    SkillTrapPreset.persistentHazard => const SkillTrapPresetValues(
        trigger: SkillTrigger.timer,
        targeting: SkillTargeting.arenaLocation,
        delivery: SkillDelivery.boundaryHazard,
        triggerIntervalSeconds: 2,
        tickIntervalSeconds: 0.25,
        areaRadiusPercent: 30,
        cooldownSeconds: 0,
      ),
  };

  static SkillDefinition apply(SkillDefinition skill, SkillTrapPreset preset) {
    final config = values(preset);
    return skill.copyWith(
      category: skill.resolvedCategory == SkillCategory.arenaTrap
          ? SkillCategory.arenaTrap
          : SkillCategory.trap,
      trigger: config.trigger,
      targeting: config.targeting,
      delivery: config.delivery,
      triggerIntervalSeconds: config.triggerIntervalSeconds,
      tickIntervalSeconds: config.tickIntervalSeconds,
      areaRadiusRatio: config.areaRadiusPercent / 100,
      cooldownSeconds: config.cooldownSeconds,
    );
  }
}
