# Batch 6C cumulative checkpoint 14

This source patch includes every changed file from checkpoints 1 through 13, plus checkpoint 14. Apply on the existing full-project baseline, not as a standalone Flutter project.

## Checkpoint 14 changes

- Fixed duplicate `maxPendingActivations` declaration in `SkillTriggerScheduler` (a Dart compile blocker).
- Made start-delay normalization finite-safe, avoiding activations scheduled at infinity.
- Kept repeat queue admission atomic, removing redundant mid-loop capacity checks.
- Corrected an earlier regression test that expected 20 accepted 128-repeat activations despite a 1,024-entry limit; now verifies rejection after 8.
- Added tests for infinite start delays and preserving existing activations when the queue is full.
- Pruned passive scheduler state when actors are no longer alive or custom passive skills are disabled/removed; cleared corresponding stale damage baselines.

## Scope limitations

This is a reliability and integration maintenance batch, not a completed trap ownership or arena end-to-end integration effort. Those are still pending. The Flutter SDK is not available here, so Dart analysis and Flutter tests were not executed. ZIP integrity and source assertions only were checked.

## Next planned substantial batch

1. Passive-trigger acceptance and retry semantics when the effect executor rejects an activation.
2. Projectile and mine ownership lifecycle across elimination, reflection and respawn.
3. End-to-end arena tests for pickup/collision/passive triggers, including rejected activations.
4. Built-in weapon compatibility regression coverage.
