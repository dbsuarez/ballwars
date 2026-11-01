# Ball Wars Post-6D Quality Pass 02

Baseline: Quality Pass 01 full Flutter project. This archive is cumulative and complete.

## Changes
1. Composed projectile impacts no longer inherit the cooldown of the weapon's earlier aimed-fire launch. This prevents projectiles that arrive before the cooldown expires from silently failing on impact.
2. Projectile impact activation still requires valid targets or independent effect steps and sufficient scheduling capacity. Rejected impacts retain the existing projectile rejection handling.
3. Impact processing does not reset the weapon's firing cooldown, allowing multiple projectiles from a volley to resolve independently.
4. Capped projectile volleys now spread across the *admitted* projectile count, not the originally requested count. A one-shot partial volley travels along the aim direction.
5. Added six unit tests covering cooldown separation, impact admission, symmetric spreads, and invalid spread values.

## Validation
- ZIP integrity and exact file membership: checked.
- Source assertions: checked.
- Flutter analyzer, test execution, Android gameplay: NOT RUN (Flutter SDK unavailable).
- Note: This change deliberately keeps the original partial-volley admission policy and collision-rejection behavior.

## Suggested test scenarios
- Fire a slow projectile with a long firing cooldown: it must still apply effects when it arrives.
- Fire a three-shot volley: all three impacts must apply if targets are valid.
- Fill the projectile budget until one slot remains: the remaining projectile must fire straight.
- Verify returning, homing and reflected projectiles, and no-target/queue-full impact rejection.
