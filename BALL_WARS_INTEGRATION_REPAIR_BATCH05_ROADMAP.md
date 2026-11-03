# Ball Wars Integration Repair Batch 05: Remaining Failures

## Source
Cumulative changes-only patch superseding Batch 04. Apply to clean approved Batch 18 baseline. Do not stack on top of earlier integration patches.

## Latest user verification (Batch 04)
- Flutter test: 1,543 passed, 3 failed, 1 skipped.
- Remaining: one trap settings widget test; two visual-effect runtime tests.

## Batch 05 implementation
1. Keep Arena traps controls grouped at the beginning of Common to avoid unstable off-screen switching among the three controls.
2. Resolve and cache missing impact/explosion artwork snapshots for events inserted directly into runtime lists (e.g., replay/externally injected effects), preserving snapshots already captured during normal gameplay. This targets both remaining visual runtime failures.

## Roadmap / verification
- Four-package integration: implemented, earlier tests largely passed, not released.
- Trap settings: repair authored, awaiting Flutter retest.
- Impact and explosion visual runtime: repair authored, awaiting Flutter retest.
- Static analysis: awaiting Flutter analyzer.
- Release: NOT READY until user confirms zero test failures and analyzer errors.

## Verify
```powershell
flutter analyze
flutter test --reporter expanded *> integration-retest-05.log
```

No Flutter/Dart SDK available in this environment. ZIP CRC and file hashes verified; no claim of passing Flutter tests.
