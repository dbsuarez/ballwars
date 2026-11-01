# Ball Wars Batch 6B v49 (apply after v48)

Changes: `test/features/skills/skill_management_screen_test.dart` only.

- Fix the last Combine widget test: ensure the filtered Knife Volley ListTile is visible and hit-testable before tapping, then assert the editor opens. The v48 test attempted to access an Identity tab that was never mounted because its preceding tap missed an off-screen tile.
- Remove three unused imports flagged by flutter analyze.

Apply on top of v48. This is an incremental v49 patch, not a cumulative project replacement.

Validation: source-pattern assertions and ZIP integrity checked. Flutter SDK is unavailable here; run `flutter analyze` and the targeted test locally.
