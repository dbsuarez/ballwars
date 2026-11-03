# Ball Wars v1.14.40 RC Repair 01

## Source and verification
Cumulative changes-only patch based on reconstructed v1.14.40 candidate. User's 1.14.40RC.log: 1547 passed, 1 skipped, 4 failed. Flutter SDK not available in this environment; corrections are not yet retested. Not release-ready until tests pass.

## Implemented
- Retained v1.14.40 center-obstacle spawn safety and four hand artwork presentation modes.
- Retained unified trap controls in Skill Management Global Defaults and removed legacy controls.
- Added tap-accessible master override help in the new location.
- Migrated three obsolete Power-Up Tuning widget tests to Skill Management, covering accessible help, independent switches and persistence, and master override behavior.
- Updated global callout widget test to reveal its field after new trap settings shifted scroll position.
- Changed two async dialog sprite-picker context accesses to State.context after mounted checks to address use_build_context_synchronously lint.

## Verification required
1. flutter analyze
2. flutter test test/features/skills/skill_management_screen_test.dart
3. flutter test test/features/settings/power_up_tuning_screen_test.dart
4. flutter test
5. Manual phone verification for four artwork modes, trap controls, and center obstacle pickup placement.

## Release status
Implemented: yes. Flutter tests verified after repair: no. Release-ready: no.
