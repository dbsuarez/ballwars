Ball Wars Batch 6B v48: two remaining widget-test failures

Apply after v47, preserving directory structure.

1. Mechanical steps widget test: ordered effects are currently rendered in the Identity/Behavior section, not the Mechanics tab. Select the correct tab and scroll through the lazy form.
2. Combine: move the existing Combine controls to the beginning of Identity so invalid fired-skill diagnostics remain reachable; select Identity explicitly in the regression test. Save validation is unchanged.

No tests have been run in this environment (Flutter SDK unavailable). Please run:
flutter analyze
flutter test test/features/skills/mechanical_effect_steps_test.dart test/features/skills/skill_management_screen_test.dart --reporter expanded
flutter test --reporter expanded
