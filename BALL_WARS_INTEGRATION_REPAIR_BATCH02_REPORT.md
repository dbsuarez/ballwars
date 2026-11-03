# Ball Wars Integration Repair — Batch 02

## Source and scope
Cumulative patch-only package for the exact approved Batch 18 full-project baseline. Preserves Phase 1, Phase 2, Phase 4 and Projectile Reliability Batch 30 integration and all Batch 01 changes. Do not layer over another patched baseline.

## Implemented
- Avoid overflow of the hand attachment radius multiplier, falling back to the owner location for extremely large values.
- Correct the Phase 1 trap cleanup test setups: a tracked quicksand victim must actually be inside its 18%-of-arena-radius patch to be released. Preserve runtime rule that victims outside the patch are not ejected.
- Navigate to the Common tab in three trap settings widget tests before locating its controls.
- Correct Omega multi-cast snapshot test: an existing grab has advanced one simulation step when a later cast is picked up; the newly created grab retains its full timer.
- Retain Batch 01 numeric copyWith fix, ArenaDecoration import, and quicksand capacity test fixture corrections.

## Verification and risks
ZIP integrity and SHA-256 hashes verified. Flutter and Dart SDK are unavailable here. No claim that the remaining 15 tests or 33 analyzer notices pass. Two native artwork rendering tests and other potential regressions remain unverified. **Not production-ready.**

## Roadmap
| Workstream | Implementation | Flutter verification | Release readiness |
|---|---|---|---|
| Four-package integration | Included | Pending | No |
| Batch 01 root cause repairs | Included | User reported 15 remaining failures | No |
| Batch 02 targeted repairs | Authored | Pending | No |
| Remaining visual failures | Pending | Pending | No |
| Analyzer cleanup (33 notices) | Pending | Pending | No |
| Phone smoke testing | Pending | Pending | No |

## PowerShell verification
Apply this ZIP to a **fresh extraction** of the approved Batch 18 full project, then run:
```powershell
flutter pub get
flutter analyze
flutter test --reporter expanded *> integration-retest-batch02.log
```
Only after tests pass, build a phone candidate with `flutter build apk --debug` and install it with `flutter install` on a connected Android device. Do not push to GitHub master yet.
