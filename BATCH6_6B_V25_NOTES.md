# Batch 6B v25: Event-focused Skill Demo replay

- Projectile focus now pauses the real arena simulation after the first shot event observed following activation.
- Impact focus now pauses after the first hit or blast event observed following activation.
- Reports when the replay finishes without the requested event, rather than pretending an isolated effect was shown.
- Displays an explicit status message when the event is reached.
- Clears pending event watches on mode switch, reset, arena edits, and pickup/equipped inspection.
- Casting remains a full simulation replay; no fake isolated animation is claimed.

This is a cumulative patch over v24. Flutter compilation and tests have NOT run. The event-focus feature is implemented but not runtime-validated; impact detection does not yet cover every possible non-damaging effect. Batch 6B remains unverified.
