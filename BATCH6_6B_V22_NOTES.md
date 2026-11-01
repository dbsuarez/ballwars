# Batch 6B v22: asynchronous incoming-hit and replay lifecycle

- Incoming-hit artwork preparation now uses the same generation token as the main skill replay. Switching artwork mode, changing arena geometry, spawning or clearing a pickup, or closing the dialog invalidates the pending incoming-hit action.
- Stale incoming-hit failures no longer stop a newer simulation or overwrite its error status.
- Main replay explicitly stops the previous simulation before artwork preparation; pause/resume is disabled while preparing.
- All earlier cumulative Batch 6A and 6B files are retained from v21.

Validation: archive CRC and targeted source assertions passed. Flutter SDK not installed; no compilation or widget tests executed. Batch 6B remains incomplete.
