# Batch 6B consolidated lifecycle and migration integration

- Extracted actual arena held-weapon visibility into a testable lifecycle rule.
- Added tests for projectile launch, returning, spent, rethrow, owner isolation, kind isolation, and explicit overrides.
- Prevented legacy VFX migration from discarding a sprite when an explicit binding refers to a missing effect.
- Reconciled migration tests with existing-binding precedence and added capacity/atomicity coverage.
- Cumulative changed-files overlay on the 2026-10-31 1648 project baseline; includes all prior 6B patches through v35.

Validation: ZIP CRC and static source checks only. Flutter/Dart toolchain unavailable in this environment; compilation and test execution remain outstanding. Not a verified 6B release.
