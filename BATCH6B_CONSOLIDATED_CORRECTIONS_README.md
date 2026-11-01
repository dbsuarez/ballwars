# Ball Wars Batch 6B: consolidated test correction candidate

Baseline: `ballwars 2026-11-01 1032.zip`. Apply this ZIP at the project root, replacing matching paths. This is a single patch, not an accumulation of v44 plus other patches.

Includes:
- Prior analyzer fixes: DropdownButton unsupported tooltips, nullable deserialization test cases, removed API names, profile support.
- Legacy VFX round-trip test compares migration stability after defaults hydration, while retaining sprite/scale/opacity/playback preservation checks.
- Legacy artwork editor tests updated for retired controls, retaining assertions for resolved artwork and existing event binding preservation.
- Unified category filtering tests updated for the current UI.
- Skill Demo test uses an explicit projectile-based skill for shot counter and avoids unique-text assumptions for Casting.
- Mechanical steps test locates lazily built editor control before scrolling.
- Editor navigation test helper skips tabs not mounted in the current tab viewport.
- Grip preview test re-reveals lazy fields after closing the preview.
- Empty-state content scrolls when constrained instead of overflowing.
- Search filter removal test operates on the active InputChip.

Validation: ZIP integrity and file differences checked. Flutter/Dart SDK is not available in this environment, so `flutter analyze` and `flutter test` were NOT run. The patch is an integration candidate, not a verified green build. No tests were skipped or deleted to hide failures.

After application:
```
flutter analyze
flutter test --reporter expanded
```
