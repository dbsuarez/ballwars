# Ball Wars Test Feedback Patch 07 (cumulative)

Based on the post-6d quality pass 02 project with cumulative Patch 06 applied.

Changes:
- Resolve collision damage from the actual identified custom melee skill, rather than always taking the base weapon's tuning damage. Revision 1 retains legacy base-kind behavior. Revision 2 and later preserve the custom skill's damage on a secondary-only weapon; revision 3 retains separate identities for both hands.
- Direct-save skill editors remain open after a successful save and display `Skill saved.`. This preserves repeated editing, effects binding, and editor feedback workflows. Route-only editors without an onSave callback still pop their edited result for `Save Library`.

Expected to address all seven failures reported in batch6d_test(3).log; this expectation is based on source inspection, NOT a verified Flutter test run. Flutter SDK is unavailable in this environment. Please run `flutter analyze` and `flutter test --reporter expanded` on your machine.

The test suite itself is unchanged. If any tests remain failing, send the full output for source-level follow-up.
