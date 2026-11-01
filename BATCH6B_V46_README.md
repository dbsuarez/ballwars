# Ball Wars Batch 6B v46, remaining three test failures

Apply on top of v45 at the project root. This is one patch for all three remaining failures, not a replacement for the v45 source fixes.

- Mechanical effects: advance the active editor scroll position directly to find the ordered-steps control in the long Mechanics tab.
- Phone Skill Demo: bring the Spawn pickup button into view and verify hit-testability before tapping, so the test actually exercises pickup spawning.
- Combine editor: use deterministic editor scrolling to locate validation controls without tapping overlapping list content.

Validation: all three source files checked against v45 and ZIP CRC verified. Flutter SDK unavailable here; passing tests are not claimed.

Run: flutter test --reporter expanded
