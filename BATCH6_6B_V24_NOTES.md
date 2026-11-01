# Batch 6B v24: Preview restore race and configurable thrown visibility

- Prevent late asynchronous device-preference restoration from resetting an active preview or a manually spawned pickup. Restoration is generation-scoped and does not overwrite newer user interactions.
- Apply hideHeldWhileThrown to in-flight projectiles matching the equipped weapon kind rather than only hardcoding boomerang projectiles. Boomerang still defaults to hide; other weapons default to show unless explicitly configured.
- Retain previous cumulative Batch 6A and 6B source changes.

## Verification
- ZIP CRC: passed.
- Python static assertions: passed.
- Flutter analyzer and automated tests: NOT RUN (Flutter/Dart SDK absent).
- This is NOT a completed or verified 6B release. Isolated Casting/Projectile/Impact playback, lifecycle edge cases, and integration regression remain pending.

## Apply / rollback
Apply to a clean extraction of `ballwars 2026-10-31 1648.zip` (do not stack patches). Roll back by restoring the baseline or v23 cumulative patch.
