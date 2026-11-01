# Batch 6C cumulative checkpoint 16

Includes all Checkpoint 15 source changes and the following updates:

1. Passive trigger executor rejection retries at the next match frame (timer and damage-taken), with duplicate retry suppression.
2. Damage-taken retries drain even when the owner does not take further damage.
3. Elimination removes victim-owned mines, pending composed effects, effect-step jobs, damage-over-time jobs, cooldowns and scheduler state, even if automatic passive triggers are disabled.
4. Respawn removes owner-owned mines and composed projectiles and prunes projectile metadata maps.
5. Four scheduler tests for retry timing, deduplication, invalid time and numeric overflow.

Known limitation: elimination-trigger effects are not retried when rejected because their original victim target may no longer be valid. Full arena integration tests and legacy compatibility verification remain pending. Dart/Flutter SDK unavailable; no compilation or Flutter tests run.

Next batch scope: projectile reflection ownership, trap effects and elimination cleanup regression tests; passive trigger rejection integration tests; legacy weapon compatibility and final 6C integration review before 6D.
