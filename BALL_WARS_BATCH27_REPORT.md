# Ball Wars Projectile Reliability — Batch 27

Date: 2026-11-03

## Scope
Persistent multi-target contact processing only. Built on the cumulative Batch 26 patch-only ZIP.

## Implemented
- Revalidate each subsequent swept contact immediately before dispatching damage or defense. Earlier contacts and composed effects may invalidate later targets within the same step.
- Reject targets that are no longer alive, are ghosts, are now the owner, are already in hit history, or have non-finite coordinates.
- Add a three-target single-step boomerang regression scenario in both contestant-list orders.

## Verification
- ZIP CRC and manifest file presence: verified.
- Flutter analyzer/tests: NOT RUN (Flutter/Dart SDK unavailable in this environment).
- No release or phone testing performed.

## Remaining
- Verify general piercing semantics across all applicable weapons and composed skills.
- Verify All-Out thread interactions and same-step reflection/obstacle ordering in integration tests.
- Run flutter analyze, flutter test --reporter expanded, flutter build web --release on full integrated project.
- Phone test and obtain user approval before deploying.

## Baselines
Production: v1.14.38 (user-confirmed). Patch source: cumulative Batch 26, not a fresh diff against production.
