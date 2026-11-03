# Ball Wars Projectile Reliability Batch 19

Baseline: confirmed deployed v1.14.38. Cumulative patch includes identifiable modified files through Batch 18 and this Batch 19 improvement.

## Change
Homing target acquisition now resolves exactly equal finite distances using stable contestant ID rather than iteration order. Strictly closer opponents always take precedence. Existing target eligibility, previous-hit exclusions, and overflow checks are preserved.

## Regression coverage
- Equidistant opponents with reverse lexical/list order select lower stable ID.
- Strictly closer opponent wins even when its ID sorts later.

## Validation
- Source-level change and regression tests added.
- ZIP archive CRC checked and contents verified.
- Flutter analysis and Flutter tests NOT RUN (Flutter/Dart SDK unavailable in this environment).

## Installation
Apply over the existing integrated project containing Batches 02-18; preserve the project directory structure. This archive is a cumulative changed-files patch, NOT a standalone full project and NOT a verified complete diff from v1.14.38.
