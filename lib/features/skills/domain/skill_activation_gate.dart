/// Pure match-step cooldown math shared by composed skill activations.
///
/// Match time is expressed in simulation steps (60 per second), not wall time.
/// The ready step is inclusive, so a skill can fire on the exact expiry step.
class SkillActivationGate {
  const SkillActivationGate._();

  static bool isReady(int currentStep, int? readyStep) =>
      readyStep == null || currentStep >= readyStep;

  /// An activation is admitted only when cooldown, target selection and
  /// scheduling capacity all allow it. Rejected activations consume nothing.
  /// Impact of a projectile already fired is independent of the firing
  /// cooldown. Target validity and effect queue capacity still apply.
  static bool canResolveProjectileImpact({
    required bool hasTargetsOrIndependentEffects,
    required bool hasScheduleCapacity,
  }) => hasTargetsOrIndependentEffects && hasScheduleCapacity;

  static bool canActivate({
    required int currentStep,
    int? readyStep,
    required bool hasTargetsOrIndependentEffects,
    required bool hasScheduleCapacity,
  }) => isReady(currentStep, readyStep) &&
      hasTargetsOrIndependentEffects && hasScheduleCapacity;

  static int nextReadyStep(int currentStep, double cooldownSeconds) {
    if (!cooldownSeconds.isFinite || cooldownSeconds <= 0) {
      return currentStep;
    }
    return currentStep + (cooldownSeconds * 60).ceil();
  }
}
