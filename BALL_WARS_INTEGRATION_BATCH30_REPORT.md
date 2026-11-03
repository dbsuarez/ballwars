# Ball Wars consolidated integration: Phase 1 + Phase 2 + Phase 4 + Projectile Reliability Batch 30

## Status
Integrated patch candidate only. **Not tested, not production-ready.** No GitHub deployment performed.

## Source and merge method
- Starting full-project baseline: `ballwars_batch18_center_wall_contact_cumulative.zip`.
- Previously consolidated Phase 1 patch33, Phase 2 FINAL, Phase 4 FINAL, and projectile Batch22.
- This update supersedes **Batch22 with cumulative Batch30** while preserving the other phases.
- For overlapping existing files, applied changes between Batch22 and Batch30 onto the previous integrated result using `git merge-file` with Batch22 as the common ancestor.
- New Batch30 tests and its progress/audit reports were included. Stale source-package SHA256_MANIFEST.txt was excluded; see the regenerated integration manifest.
- All modified files are relative to Batch18, not a full-project ZIP.

## Batch30 additions
See included `BALL_WARS_BATCH24_REPORT.md` through `BALL_WARS_BATCH30_FINAL_IMPLEMENTATION_AUDIT.md` and `BALL_WARS_PROJECTILE_RELIABILITY_PROGRESS.md`. Batch30's final audit adds regression cases for non-returning pistol projectiles stopping at the first target, while retaining returning-projectile multi-target behavior.

## Verification
- Integrated ZIP CRC and per-file SHA256 checks performed.
- No Git textual conflict markers in integrated Dart files.
- Flutter/Dart not available in the consolidation environment: `flutter analyze`, `flutter test`, and `flutter build web --release` **not run**.
- The fact that textual merging succeeded does not prove semantic correctness. `power_up_system.dart` has multiple phase contributions and requires particular attention.

## Testing and release gates
1. Extract the exact Batch18 full-project baseline into a clean directory.
2. Extract this cumulative patch-only ZIP over it, preserving project-relative paths.
3. Run `flutter pub get`, `flutter analyze`, `flutter test --reporter expanded`, and `flutter build web --release`.
4. Verify trap controls, native built-in skills, artwork compatibility, homing/reflection, returning shots, and non-piercing pistol contacts on a phone.
5. Fix any compile or runtime issues before deployment. Do not apply blindly to a different source baseline.

## PowerShell test workflow
```powershell
New-Item -ItemType Directory -Force .\ballwars-integration-check | Out-Null
Expand-Archive .\ballwars_batch18_center_wall_contact_cumulative.zip .\ballwars-integration-check -Force
Expand-Archive .\ballwars_four_package_integration_batch30_cumulative_patch_only.zip .\ballwars-integration-check -Force
Set-Location .\ballwars-integration-check
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter build web --release
```
