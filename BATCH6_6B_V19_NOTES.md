# Batch 6B v19: asynchronous preview cancellation guard

The Skill Demo previously could activate a stale replay after a mode switch or reset while asynchronous sprite preparation was in progress. This update adds a generation token checked after artwork preparation, and invalidates pending starts on mode change, reset, pickup preview and dispose. Stale errors and loading-state updates are ignored.

Cumulative over v18. Static source assertions and ZIP CRC passed. Flutter analysis and widget tests were not run. Remaining 6B work includes isolated mode playback and full integration validation.
