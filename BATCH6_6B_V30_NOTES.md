# Batch 6B v30: reusable held-weapon presentation rule

- Generalized the Hide held artwork while thrown editor setting to projectile-delivery weapons rather than Boomerang alone.
- Added SkillDefinition.hidesHeldDuringFlight as a reusable presentation-only rule consumed by the arena painter.
- Preserved the default: Boomerang hides in flight, ordinary guns do not. Explicit overrides take precedence.
- Added tests for both defaults, explicit overrides, and persistence.
- Retains existing active-projectile/spent checks for automatic restoration.

## Outstanding
- No full weapon-class/attack-delivery schema or comprehensive interruption parity testing.
- Mode-specific demo and VFX parity require integrated Flutter tests.
- Flutter SDK unavailable locally: neither flutter analyze nor flutter test was executed.

## Patch
Cumulative changed files over the authoritative 2026-10-31 1648 baseline. Supersedes v29. Rollback by reapplying the baseline and prior approved patch.
