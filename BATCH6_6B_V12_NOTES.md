# Batch 6B v12: configurable Boomerang held-art visibility

Cumulative changed-files patch relative to ballwars 2026-10-31 1648.zip, includes 6A and 6B v1-v11.

- Nullable hideHeldWhileThrown property; null keeps previous Boomerang default.
- JSON roundtrip, copyWith, and reset support.
- Editor switch for Boomerang; defaults to enabled and permits explicit override.
- Arena painter respects the per-skill setting when a Boomerang projectile is active.
- Regression test for persistence and nullable override.

Limitations: other projectile weapons are not supported by this switch; mode-specific demo playback and VFX retirement remain unfinished. Flutter analyze/test not run (SDK absent). ZIP integrity verified.
