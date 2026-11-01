# Ball Wars Batch 6D - Native Targeting and Lifecycle Integration

Cumulative source patch superseding the previous 6D hybrid-contact package.

## Implemented
- Omega Tendrils native target selection extracted to a deterministic reusable selector.
- Arena order and default all-opponent semantics retained; configured limits honored.
- Owner, inactive targets and duplicate target references excluded.
- Shadow Clone respawn cleanup no longer depends on the older simulation revision guard; surviving clones retarget after respawn.
- Burst shell-skill metadata cleared on owner respawn.
- Four new target-selection regression tests.

## Verification
- ZIP CRC/integrity and source assertions passed.
- Flutter SDK/Dart analyzer not available in this execution environment; compilation and tests NOT run.
- Android arena playtesting NOT run.
- This is a source patch, not a standalone Flutter project.

## Remaining before 6D closure
- Validate native and composed advanced-skill interactions with full-project Flutter analyzer/tests.
- Add arena-level integration tests covering reflection, native cinematics, hybrid contact, and legacy weapons.
- Confirm full behavior of Shadow Clone/Omega Tendrils in a running match.
