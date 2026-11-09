# Ball Wars v1.14.68

Each ball now starts with an independent random heading across the full circle, instead of the shared clockwise/counterclockwise pattern. New matches and Power-up Test use simulation revision 12. Initial speed distribution and bounce physics are unchanged; older replays keep their historical launch behavior.

## Validation

- 77 focused simulation and replay tests passed, including an eight-ball seeded replay round-trip.
- Flutter static analysis: no issues found.
- No full-suite rerun or physical-device acceptance was performed for this release.

## Publication

2026-11-09: push master for web deployment and annotated tag v1.14.68 for the existing APK release workflow. Workflow completion and published artifacts are checked manually by the user.
