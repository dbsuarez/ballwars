# Batch 6B v21: stop replay on pickup inspection

The arena preview mutation path now explicitly stops the skill simulation before modifying the pickup field. Previously stopping only the ticker could leave controller.playing=true, making the UI display Playing and allowing a later resume to advance the stale simulation. The stopPlayback method preserves field objects so Clear pickup still operates on the existing field. Added regression coverage.

Cumulative over v20. ZIP CRC validated. Flutter SDK unavailable; no compilation or widget tests run. Batch 6B not complete.
