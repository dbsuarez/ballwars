# Ball Wars v1.14.51 RC02 — Target Lifecycle Repair

## Source and scope
Cumulative **patch-only** archive. All RC01 payload files are retained, including the cumulative v1.14.50 RC03 changes. Apply this over the current v1.14.51 RC01 or v1.14.50 source checkout; do not replace the project with the historical v1.14.41 baseline.

## Reported local results
User-provided RC01 log ends at **+1603 ~1 -3: Some tests failed**. Three failures relate to selection of opponents that have lost the last life/thread before `isEliminated` is set. Two analyzer info notices concern braces and a redundant test import.

- `power_up_effects_test.dart`: owner was aiming at an already-dead ball, changing firing angle.
- `shadow_clone_test.dart`: clone incorrectly retained a killed target instead of retargeting.
- `shadow_clone_test.dart`: clone did not enter vanish behavior after the last opponent died.

## Repairs made
1. `CombatTargeting.select` accepts an optional `isEligible` predicate and applies it before target ranking or hysteresis retention.
2. Both match aimed targeting and homing projectile reacquisition pass the *existing* `PowerUpSystem._alive` rule. This rule uses Arsenal life >= 1 or All-Out remaining fan threads and excludes formally eliminated contestants. The selection service itself remains reusable without assumptions about match mode.
3. Added a regression test for a contestant with zero playable life, not yet formally marked eliminated, including previous-target retention and no-valid-opponent conditions.
4. Added braces to the reported `centerObstacleBlocks` guard and removed the redundant `dart:ui` test import.

## Scope and safeguards
No change to damage, melee hit checks, projectile sweep geometry, center-wall contact ordering, attack animation, VFX z-order, or existing GitHub Actions triggers. Existing RC01 functionality remains in the cumulative archive.

## Progress roadmap
| Area | Implemented | Tests authored | User Flutter verified | Release ready |
|---|---|---|---|---|
| RC01 sticky/obstacle-aware targeting | Yes | Yes | RC01 suite failed | No |
| Dead-before-elimination eligibility | Yes | Yes | Pending | No |
| Shadow Clone lifecycle compatibility | Source repair | Existing tests | Pending | No |
| Homing target lifecycle compatibility | Yes | Existing/new filtering tests | Pending | No |
| Analyzer cleanup | Yes | N/A | Pending | No |
| Original Pages master-only workflow | Retained | N/A | Pending | No |
| Visual combat diagnostics overlay | Not implemented | No | No | No |
| Skill Demo center-obstacle simulator | Not implemented | No | No | No |

## Validation
Flutter and Dart executables were unavailable in the packaging environment. Source edits and archive/manifest integrity were checked, **not Flutter compilation or test execution**.

Run on your Windows project after applying RC02:
```powershell
flutter analyze
flutter test -p vm --reporter expanded
```
If failures remain, send the new analyzer/test log. Do not deploy until these checks pass and the new target-selection behavior has received visual verification.
