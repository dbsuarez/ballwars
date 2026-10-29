import 'dart:math' as math;
import 'dart:ui';
import '../../arena_simulation/application/match_simulation_controller.dart';
import '../../arena_simulation/domain/power_up.dart';
import '../../arena_simulation/domain/power_up_config.dart';
import '../../ball_management/domain/custom_ball.dart';
import '../../match_setup/domain/match_config.dart';
import '../domain/skill_library.dart';

/// Isolated, repeatable editor scenario. Nothing is saved to player settings.
class SkillDemoController {
  SkillDemoController({
    required this.skill,
    required this.library,
    required this.tuning,
  }) {
    reset();
  }
  final SkillDefinition skill;
  final SkillLibrary library;
  final PowerUpConfig tuning;
  late MatchSimulationController match;
  bool facingRight = true;
  bool playing = false;
  bool started = false;
  double elapsed = 0;
  double speed = 1;

  /// Null keeps the skill-aware automatic spacing; 0 is near, 1 is far.
  double? distanceRatio;
  double get _expectedDuration {
    var timeline = skill.durationSeconds ?? 3;
    var delay = 0.0;
    for (final step in skill.effectSteps) {
      delay += step.delaySeconds;
      timeline = math.max(timeline, delay + (step.durationSeconds ?? skill.durationSeconds ?? 3));
    }
    return skill.startDelaySeconds + skill.repeatCount * skill.repeatIntervalSeconds + timeline + 3;
  }
  double get duration => _expectedDuration.clamp(6, 45);
  bool get timeLimited => _expectedDuration > 45;
  void reset() {
    playing = false;
    started = false;
    elapsed = 0;
    match = MatchSimulationController(
      const [
        CustomBall(
          id: 'demo-caster',
          name: 'Caster',
          primaryColor: Color(0xffff6156),
          glowColor: Color(0xffff6156),
        ),
        CustomBall(
          id: 'demo-target',
          name: 'Target',
          primaryColor: Color(0xff55aaff),
          glowColor: Color(0xff55aaff),
        ),
      ],
      arenaRadius: 180,
      ballScale: 1.7,
      seed: 42,
      mode: MatchMode.arsenal,
      lookAhead: false,
      slowMotionLines: 0,
      endlessBattle: true,
      automaticSpeedUp: false,
      powerUpKinds: const {},
      customSkillIds: const {},
      tuning: tuning,
      skillLibrary: library.withDefinition(
        skill.copyWith(enabled: true),
        tuning,
      ),
    );
    match.powerUps!.automaticSpawning = false;
    match.powerUps!.automaticPassiveTriggers = false;
    final owner = match.state.balls.first, target = match.state.balls.last;
    final melee =
        skill.resolvedCategory == SkillCategory.weapon &&
        (skill.isComposed
            ? skill.trigger == SkillTrigger.collision
            : !skill.baseKind.isGun);
    final nearbyEffect = const {
      SkillDelivery.aura,
      SkillDelivery.orbit,
      SkillDelivery.area,
    }.contains(skill.delivery);
    final automaticGap = melee
        ? owner.radius + 2
        : nearbyEffect
        ? math.max(owner.radius + 2, math.min(65, 180 * skill.range * .4))
        : 65.0;
    final minGap = owner.radius + 2;
    final maxGap = math.max(
      minGap,
      match.arenaRadius - math.max(owner.radius, target.radius) - 3,
    );
    final gap = distanceRatio == null
        ? automaticGap
        : minGap + (maxGap - minGap) * distanceRatio!.clamp(0, 1);
    final sign = facingRight ? 1.0 : -1.0;
    owner.position = Offset(-gap * sign, 0);
    target.position = Offset(gap * sign, 0);
    if (distanceRatio == null &&
        (skill.targeting == SkillTargeting.arenaLocation ||
            skill.delivery == SkillDelivery.boundaryHazard)) {
      target.position = Offset(150 * sign, 0);
    }
    owner.velocity = target.velocity = Offset.zero;
    owner.aimTarget = target;
    if (skill.canHeal ||
        const {
          PowerUpKind.apple,
          PowerUpKind.friedChicken,
          PowerUpKind.vampire,
        }.contains(skill.baseKind)) {
      owner.life = 45;
    }
    if (skill.resolvedCategory == SkillCategory.weapon &&
        skill.baseKind.isWeapon) {
      owner.equipWeapon(
        skill.baseKind,
        dualWield: false,
        skillId: skill.id,
        twoHanded: switch (skill.handedness) {
          SkillHandedness.carrierDefault => null,
          SkillHandedness.oneHanded => false,
          SkillHandedness.twoHanded => true,
        },
      );
    }
  }

  void activate() {
    reset();
    started = true;
    match.powerUps!.activateTestSkill(
      match.state.balls.first,
      match.skillLibrary.byId(skill.id, match.tuning)!,
      match.state.balls.last,
    );
    if (!skill.isComposed && skill.baseKind == PowerUpKind.speed) {
      final toward =
          match.state.balls.last.position - match.state.balls.first.position;
      match.state.balls.first.velocity = toward / toward.distance * 70;
    }
    match.powerUps!.persistentEffects.sync();
    playing = true;
  }

  void step(double realSeconds) {
    if (!playing || !realSeconds.isFinite || realSeconds <= 0) return;
    final delta = math.min(realSeconds, .1) * speed;
    elapsed += delta;
    match.tick(delta);
    if (elapsed >= duration) playing = false;
  }

  void incomingHit() {
    if (!started || elapsed >= duration) {
      if (!skill.isComposed && skill.baseKind == PowerUpKind.shield) {
        reset();
        started = true;
        playing = true;
      } else {
        activate();
      }
    }
    final target = match.state.balls.first, attacker = match.state.balls.last;
    match.powerUps!.pickUp(
      attacker,
      FieldPowerUp(
        kind: PowerUpKind.pistol,
        skillId: 'builtin.pistol',
        position: attacker.position,
        spawnStep: match.stepCount,
      ),
    );
    attacker.aimTarget = target;
    attacker.aimLeft = 1;
    playing = true;
  }
}
