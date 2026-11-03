# Ball Wars v1.14.42 Hand Artwork Cumulative Patch: Regression Repair

## Base
Apply over the v1.14.41 full-project baseline. This cumulative patch retains all six files from the earlier hand-artwork batch.

## Repair
- Omit six new attachment/offset JSON fields at their legacy defaults, preserving byte-identical old replay snapshots.
- Serialize non-default attachments and offsets normally.
- Replace two deprecated DropdownButtonFormField.value parameters with initialValue.
- Add regression test for default-key omission and non-default-key persistence.

## Existing changes retained
Independent left/right/both sprite and effect attachment, independent X/Y offsets, runtime rendering and Skill Demo integration, JSON and validation tests.

## Verification and roadmap
- ZIP CRC and manifest hashes checked during packaging.
- User's previous analyzer showed two deprecation infos and replay snapshot mismatch. Repairs have not yet been run through Flutter.
- Flutter/Dart SDK unavailable in this environment. Pending: flutter analyze, flutter test, phone/Skill Demo visual acceptance.
- Not release-ready until those checks pass.

## Commands
flutter analyze
flutter test test/features/skills/skill_apply_to_all_test.dart --reporter expanded
flutter test test/features/skills/hand_artwork_attachment_settings_test.dart --reporter expanded
flutter test
