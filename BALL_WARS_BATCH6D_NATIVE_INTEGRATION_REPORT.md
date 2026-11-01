# Batch 6D native advanced-skill integration

## Implemented
- Native Shadow Clone cinematic now reads projectileCount from the active skill library entry as its clone/strike count, with existing tuning retained when unset. The existing freeze-time sequence, animation and damage execution remain native.
- Native Omega Tendrils now reads projectileCount as a target cap, retaining the historical all-opponents behavior when unset. Target selection is deterministic in the existing match ball order.
- Respawn clears native Omega Tendrils involving the respawned ball, preventing an earlier-life grab from completing after reset.
- Added a pure native advanced skill configuration adapter and four regression tests for defaults, bounds and overrides.
- Preserved cumulative 6C and earlier 6D changes.

## Limits and verification
- The native cinematic effects remain separate from composed skill execution. This patch does not claim full native/composed unification or full hybrid combat integration.
- ZIP integrity and source assertions checked. Flutter SDK unavailable; no analyzer, Flutter tests or Android gameplay verification performed.
- This is a cumulative source patch, not a standalone Flutter project.

## Next work before 6D can close
- Native/composed advanced-skill effect parameters and targeting beyond count.
- Hybrid weapon dual-mode collision and aimed-fire integration tests.
- Reflection, elimination and respawn ownership regression coverage.
- Legacy behavior regression and Flutter compile/test verification.
