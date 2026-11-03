# Ball Wars Integration Repair — Batch 01

## Baseline
Exact consolidated Phase 1 + Phase 2 + Phase 4 + Projectile Reliability Batch 30 patch, applied over approved Batch 18 full-project source.

## Changes
- `SkillDefinition.copyWith`: accept `int` or `double` for nullable floating-point fields (`durationSeconds`, `omegaSlamOffsetRatio`, `omegaSlamVelocityMultiplier`), preserving the sentinel distinction between omitted and explicitly null.
- Fix `ArenaDecoration` missing import in quicksand capacity eviction regression test.
- Correct quicksand cleanup test fixtures to place affected balls inside the hazard radius (0.18 × 260 = 46.8), rather than at distances 90/100. The runtime correctly releases tracked victims only when actually inside a patch.
- Remove unused `skill_visual_effect.dart` import.

## Validation status
ZIP and SHA-256 integrity verified. Flutter/Dart unavailable here, so analyzer and tests have NOT been executed. Other analyzer notices and test failures may remain. Not release-ready.

## Next verification
Run `flutter analyze` and `flutter test --reporter expanded` on the exact Batch 18 baseline with this cumulative patch applied. Share the new log for the next substantial repair batch.

## Roadmap
| Area | Implemented | Verified | Release-ready |
| --- | --- | --- | --- |
| Phase 1, 2, 4 and Projectile Batch 30 integration | Yes | No | No |
| Numeric cast crash | Fix authored | Flutter execution pending | No |
| Quicksand test setup | Fix authored | Flutter execution pending | No |
| Missing ArenaDecoration import | Fix authored | Flutter execution pending | No |
| Remaining failing tests and analyzer notices | Pending | No | No |
