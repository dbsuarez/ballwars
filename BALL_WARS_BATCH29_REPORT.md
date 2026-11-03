# Ball Wars Batch 29 — Simultaneous persistent contacts

## Implemented
- Fixed same-frame equal-time swept target contacts being silently dropped after the first defender.
- Maintained hit-history deduplication and stable contestant-ID ordering.
- Added overlapping-target regression in normal and reversed contestant order.

## Verification
- Static source assertion and ZIP CRC/integrity: passed.
- Flutter analyzer, flutter test, web build: NOT RUN (SDK unavailable).
- This does NOT implement a new generic piercing configuration for non-returning shots; no such policy was confirmed in the inspected projectile model.

## Release
Not merge-ready; v1.14.38 remains the confirmed production baseline.
