# Ball Wars Integration Repair Batch 03: Analyzer Cleanup

## Scope
Cumulative changes-only patch, applied over a CLEAN Batch 18 full-project baseline. Supersedes Repair Batch 02; includes previous integrated phases and fixes.

## Changes
- Added braces to 18 flagged single-line if/continue/return branches in four production Dart files, preserving branch behavior.
- Removed two unused local `skill` bindings in `power_up_painter.dart`.
- Simplified null-aware access in `native_advanced_skill_config.dart`.
- Removed ten analyzer-flagged redundant `dart:ui` imports and one unused `power_up_config.dart` import in regression tests.
- Retains all prior Batch 02 repairs.

## Verification
ZIP CRC and per-file SHA-256 verified. Dart/Flutter SDK not installed here, so `flutter analyze` and `flutter test` have NOT been run. No claim of clean analyzer or passing tests is made.

## Test log from user (Batch 02)
1538 passed, 6 failed, 1 skipped. Failures: 3 trap settings widget tests, 1 hand placement fallback, 2 native visual rendering tests. These six test failures are NOT resolved by this analyzer-only cleanup batch. Further source-level diagnosis is required.

## Roadmap
| Workstream | Implemented | Flutter verified | Release-ready |
| --- | --- | --- | --- |
| Phases 1/2/4 + projectile Batch 30 | Yes | No | No |
| Repair Batches 01/02 | Yes | Six failures in Batch 02 | No |
| Analyzer cleanup Batch 03 | Yes | Pending | No |
| Six remaining test failures | Pending | Failing in Batch 02 | No |
| Android phone build | Pending | Pending | No |
