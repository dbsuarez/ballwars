# Batch 6B v32: Preview regression alignment and pause-time safety

- Updated an existing widget test that still expected the retired generic "Replay skill in arena" button label. The Projectile mode now intentionally shows "Replay to first projectile".
- Clear the frame-time baseline when event-focused playback automatically pauses, avoiding a stale elapsed-time delta when playback resumes.
- Preserves all v31 changes and previous cumulative changes.

Validation: ZIP CRC and source assertions passed. Flutter SDK is not installed; compilation and automated tests have not been executed. Batch 6B is not yet certified complete.
