# Batch 6B v31: bounded replay lifecycle

- Guard Pause/Resume against restarting a completed or unstarted simulation.
- Added a controller regression test for bounded replay completion and explicit replay reset.
- Retained all cumulative changes through v30.

Validation: ZIP CRC and source assertions only. Flutter SDK unavailable; analyzer and widget tests not run. Batch 6B is not certified complete.
