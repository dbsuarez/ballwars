# Batch 6C cumulative checkpoint 11: activation safety batch

Includes all changed files from Checkpoints 1 through 10 plus Checkpoint 11. This is a cumulative patch, not the complete Flutter project.

## Checkpoint 11 changes
- Pickup-triggered composed skills are only removed from the field after an activation is accepted. Rejected cooldown, empty-target and capacity cases leave the pickup available.
- Collision-triggered composed weapons are only consumed after a successful activation.
- Composed execution now reports admission as a boolean.
- Cooldown is committed only after target and scheduling-capacity checks succeed, avoiding wasted cooldowns.
- Uses consistent inclusive step-based cooldown math and rounds fractional cooldowns up.
- Adds a reusable activation admission gate with four focused regression tests.

## Validation
- ZIP integrity and structural source checks only.
- Flutter SDK unavailable: tests, analyzer and Android runtime are not verified.
- No manual user verification requested.

## Remaining work
- Arena integration tests for pickup and collision consumption.
- Projectile impact and passive trigger lifecycle regression tests.
- Flutter analyzer/test run on a configured SDK.
