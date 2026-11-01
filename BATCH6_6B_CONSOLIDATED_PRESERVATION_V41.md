# Batch 6B consolidated preservation and verification pass (v41)

- Audited bulk VFX migration for dangling Explosion bindings. Fixed a data-loss case where an Impact conversion could remove the legacy fallback still used by Explosion.
- Updated dry-run preflight to count that conversion as blocked, matching actual migration.
- Added fail-closed checks for Casting, Impact, and Explosion presentation (sprite, scale, opacity, tint, positioning, facing, playback and duration) for every migrated override and custom skill. Conversion aborts without returning a partial library on mismatch.
- Added a mixed-library regression matrix covering dangling bindings, valid Impact with missing Explosion, JSON round-trip, idempotence and deterministic ID collision resolution.
- Includes all cumulative v40 source and tests.

Verification: ZIP CRC and archive member consistency passed. Flutter/Dart SDK not available in runtime; Flutter tests are NOT claimed to have run. Device testing is not yet requested.
