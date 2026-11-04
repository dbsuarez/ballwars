# Ball Wars v1.14.50 RC03 — Cumulative Repair and Progress

## Reported regression
- RC50_failures.txt shows one failed automated test: `secondary-only equipment artwork keeps its actual slot index`, `test/features/arena_simulation/presentation/scoreboard_overlay_test.dart:85`.
- Expected slot callback sequence: `[1]`. RC02 observed `[1, 1]`.
- Root cause: RC02 resolves `artworkTint` twice for a held weapon, once for SkillArtworkTint.begin and again for the newly queued Held Attack VFX foreground overlay.

## Repair
- Capture `weaponTint` exactly once for each held slot and for each transient melee visual slot.
- Reuse that tint for the ordinary held sprite and the delayed foreground VFX, retaining correct z-order and exact slot identity.
- Does not disable or remove any visual layer and does not loosen the existing test assertion.
- Full cumulative payload includes all source, test and workflow files from RC02, replacing only `power_up_painter.dart`; report and manifest updated.

## Validation
- Source-level assertion checked that both normal held-slot and transient visual-slot paths resolve tint once; all duplicate callback expressions removed from those paths.
- Cumulative ZIP CRC and SHA256 manifest verified.
- Flutter is not installed here, so **Dart tests and analysis have not been executed on RC03**.
- The uploaded RC50 test log reached +1592 with 1 recorded failure and 1 pending/skipped (~1); this does not certify RC50.

## Roadmap
| Area | Implementation | Test/release status |
| --- | --- | --- |
| v1.14.50 animation/preview/version changes | Carried from RC02 | Needs user Flutter test/visual verification |
| Held VFX foreground z-order | Retained | Needs visual verification |
| Single artwork-tint callback per weapon slot | Fixed in RC03 | Existing regression test must be rerun |
| Web and APK version synchronization | Carried from RC02 | CI still unverified |
| Release v1.14.50 | Not performed | Hold until tests and visual checks pass |

## Windows PowerShell verification
Apply this ZIP over the current RC50 source (not an older baseline), then run:

```powershell
git diff --check
flutter analyze
flutter test -p vm test/features/arena_simulation/presentation/scoreboard_overlay_test.dart --reporter expanded
flutter test -p vm --reporter expanded
```

## Recommended next action
If test output is clean, visually confirm Held Attack VFX remains above the held weapon (including secondary weapon) and confirm both facing directions before release.
