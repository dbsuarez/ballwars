Batch 6B v27: Event-focused demo coverage.

- Casting focus now pauses at first casting or muzzle artwork event.
- Projectile focus also detects projectiles spawned without a shot counter increment.
- Impact focus includes slashes, blocks and visible weapon impact effects.
- Event baselines now come from a fresh isolated match before activation, preventing prior replay counters from masking new events.
- Added replay reset regression test.

Validation: ZIP CRC passed; Flutter/Dart compilation and tests not run (SDK unavailable).
Batch 6B still needs runtime validation and further coverage; not certified complete.
