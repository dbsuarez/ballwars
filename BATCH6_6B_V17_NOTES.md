# Batch 6B v17: Connect preview-mode action

The v16 `_previewFocusedArtwork` method was never wired to a button. Added an accessible explicit preview action for the selected artwork mode. Pickup places an arena pickup; other modes accurately replay the complete skill. Preserved Edit artwork deep links. Extended the mobile widget test to exercise pickup spawning and mode-specific action labels.

This is a cumulative patch over the authoritative 2026-10-31 1648 baseline, including 6A and 6B through v16. Flutter SDK unavailable, so compilation/widget tests not executed. ZIP integrity verified.
