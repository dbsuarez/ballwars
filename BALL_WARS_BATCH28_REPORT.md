# Ball Wars Batch 28: Persistent Multi-Target Traversal

Date: 2026-11-03

## Changes

- Extend All-Out thread cutting across each actually traversed segment after a returning projectile's first ball collision. The prior implementation cut only the segment before the first target.
- Stop cutting along the original sweep when a defender reflects or absorbs the projectile.
- Stop cutting at a circular or square center obstacle rather than processing thread intersections beyond the wall.
- Preserve existing contact-time ordering, per-flight hit history, and defense/ownership semantics.
- Add regression tests for a second-contact mirror blocking a third defender (both contestant orders) and a previously-hit defender being skipped while later defenders are contacted.

## Verification

- Cumulative ZIP integrity and file hashes checked during packaging.
- Flutter/Dart SDK not installed in this environment. Analyzer, Flutter tests, and release build **not run**.
- Thread-cutting behavior is code-reviewed but does not have a new executable All-Out thread regression test; integration validation remains mandatory.

## Release gate

Not ready to merge/deploy. Production remains v1.14.38. Milestone 7 remains implementation-in-progress until generalized piercing policies and comprehensive regression verification are complete.
