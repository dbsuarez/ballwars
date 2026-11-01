# Batch 6B v29: Preview failure and focus-state hardening

Cumulative over v28, preserving the previous 6A and 6B changes.

- Runtime ticker errors now clear the pending event target and event status, stop the demo via its normal stopPlayback lifecycle, clear the ticker timestamp, and guard UI updates after disposal.
- Reselecting an already selected artwork focus no longer silently clears the pending event without resetting playback. Only an actual focus change invalidates it.
- No gameplay balance or persisted skill schema changes.

Validation: source replacement assertions and ZIP CRC verified. Flutter/Dart toolchain unavailable; compilation and automated tests NOT run. Batch 6B is not release-verified.
