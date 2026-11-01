# Batch 6D: Hybrid contact integration

## Implemented
- Hybrid composed aimed-fire weapons with positive melee reach now activate their configured composed effect on contact and in extended melee reach, while retaining aimed-fire capability.
- Existing composed collision skills retain contact execution.
- Rejected contact activation does not consume the equipped weapon; accepted contact activation uses the existing consumption path.
- Legacy non-composed weapons and ranged-only aimed-fire skills are excluded from this new contact policy.
- Five focused policy regression tests added.

## Known limitations
- A hybrid melee strike consumes the weapon under existing collision semantics, so it cannot fire after that contact. The ranged mode remains available until contact consumes the item.
- Native Shadow Clone and Omega Tendrils remain separate from the composed executor.
- This is a cumulative source patch. Flutter/Dart SDK not installed; compilation, tests, Android gameplay and full compatibility verification not run.

## Remaining 6D closure requirements
- Native advanced-skill parameter/effect integration beyond target count.
- Arena integration tests for dual-mode combat, reflection, elimination and respawn.
- Flutter analyzer and test suite, followed by gameplay verification.
