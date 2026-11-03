# Ball Wars v1.14.44 - Live Preview Expansion (development checkpoint)

## Source
v1.14.41 baseline with v1.14.42 artwork and v1.14.43 settings overlays, plus the previously created v1.14.44 live-preview extension. This checkpoint is not a release.

## Implemented in source, unverified by Flutter
- Existing GripPreviewDialog now supports drag-to-position of held sprite and hand effect. The user selects the layer to drag; both layers retain independent X/Y offsets. Movement is scaled by ball radius and clamped to editor limits.
- Reset both held/effect offsets in the preview. Changes remain unsaved until Done and editor Save; Cancel discards changes.
- Held and pickup preview cards are embedded directly in the Held & pickup editor and reflect artwork selection and scale as the editor state changes.
- Existing animated SpriteThumbnail reused to show projectile and impact artwork in the grip preview, with built-in/missing sprite fallback messaging.
- Existing projectile origin EffectPlacementPreview, AreaEffectPreview, and existing Skill Management Visual Events previews retained instead of being duplicated.
- Added unit tests for independent drag offsets, clamping, and nonfinite input.

## Remaining work / limitations
- Dragging is for held/effect positioning; pickup artwork is previewed and scaled but not drag-positioned (no persisted pickup X/Y setting).
- Projectile/impact gallery uses the existing sprite thumbnail, not an in-arena simulated projectile trajectory or hit animation.
- Muzzle-flash dedicated alignment editing has not been integrated; visual-event and projectile-origin editors remain available.
- Full area/trap in-context editable preview is not added; existing area effect preview remains available.
- Flutter analyze and tests cannot be run here because Flutter/Dart SDK is unavailable. User phone testing not done.

## Release gate
Do not release until `flutter analyze`, `flutter test`, and phone checks pass. This is a source checkpoint only, not a production-ready cumulative ZIP.

## Continuation: animation and muzzle alignment (2026-11-03)
- Added `AnimatedEffectPlacementPreview` as a wrapper around the existing real placement painter, with Play/Pause and frame stepping. It does not create another renderer or change persisted skill data.
- Replaced the static projectile-origin placement preview with the animated wrapper; its launch-origin sliders still drive the same live preview.
- Added an in-context muzzle-flash alignment preview when the skill has a configured muzzle visual binding. The same Visual Events offsets, attachment and sprite are resolved from the in-progress skill and effect library.
- Added a widget regression test for the animation controls and missing-artwork fallback.
- No Flutter/Dart executable is installed in this environment, so the test is authored but not executed. Do not label the code tested or release-ready.

## Remaining acceptance / limitations
- Area and trap previews continue to use existing arena/area painters; they are not fully draggable and the editor has no persistent pickup offset fields.
- Confirm in-app visual alignment and mobile overflow on both orientations.
- Run `flutter analyze` and `flutter test` before packaging for release.

## Continuation: live area controls and regression audit (2026-11-03)
- Audited the current `GripPreviewDialog`, `AnimatedEffectPlacementPreview`, `AreaEffectPreview`, and Skill Management editor integration. Existing drag/animation tests were located and reviewed.
- Corrected the Area Effect preview so the *draft* radius, boundary style and opacity are reflected immediately rather than using the previously saved `SkillDefinition` values. The preview uses the existing area painter and overlays the configurable boundary; the game simulation and saved skill format are unchanged.
- Added `area_live_preview_test.dart` covering widget rebuilds across hidden/dashed/solid boundaries and changed radius values.
- Existing drag-offset tests and animation playback tests remain part of the test suite. The new widget test and prior tests require execution by the user; Flutter/Dart SDK is not installed here.
- Pending: integration of draggable area/trap placement with persistence, pickup X/Y persistence (requires explicit product decision), and phone acceptance. Do not mark the complete expansion release-ready.

## Continuation: animation lifecycle and regression checks (2026-11-03)
- Audited existing grip, area, and animated placement previews and corresponding tests.
- Animated placement preview now resets its frame to the beginning when the effect binding or visual role changes, while retaining the user's playback choice.
- Added a live frame counter to make stepping observable and easier to test and use.
- Extended the widget test to assert the frame counter advances and disposing a playing preview does not surface a ticker exception.
- No new persisted pickup/trap placement fields were introduced; implementing them without an agreed data model could silently alter existing game behavior.
- Flutter/Dart binaries are unavailable here; this is a source-only verification checkpoint. Existing test results from earlier releases do not verify this new patch.

## Consolidation pass: editor interactions and tests (2026-11-03)
- Added horizontal drag editing of the existing custom area radius directly on AreaEffectPreview. The callback is enabled only when Custom area radius is switched on and updates the existing numeric controller, not a new persisted field.
- Pickup preview now has a fixed-size gesture canvas with drag-to-resize, synchronized with the existing pickupDisplayScale slider. Pickup position is deliberately not saved because the current gameplay model has no pickup X/Y configuration.
- Added a widget regression for radius dragging, retaining the existing boundary, playback, and grip tests.
- No new skill serialization fields or gameplay offsets were introduced. No SDK is installed, so analyzer and Flutter test execution must be done by the user.
- Remaining acceptance: confirm on-device layout, preview-to-game alignment, and whether pickup/trap world-position editing is desired as a separate gameplay feature.

## Held weapon slash/thrust extension (2026-11-03)
- Added independent `HeldAttackAnimation` presentation enum: slash, thrust, none. Null retains legacy rendering for existing saves, including Knife.
- Added optional `held_attack_animation` JSON key and copyWith support. No changes to attack mechanics, damage, or projectile launch scheduling.
- Wired per-equipped-skill animation through ArenaPainter to PowerUpPainter. Slash rotates and orbits the held sprite around the ball, thrust moves it forward and back, none leaves it steady. Legacy null retains previous recoil/drop/fade.
- Added Held attack animation dropdown in Skill Management and the existing GripPreviewDialog, with scrub-able attack-frame slider. Changes remain draft until Done and Save.
- Added tests for legacy serialization, slash roundtrip and independent delivery, and preview selection reset.
- **Limitations:** Animation is driven by the existing fired-weapon hold timer. This covers skills that trigger that timer (including fired projectiles); melee-only hit events without a fired timer are not newly instrumented. No dedicated animation speed/angle settings; slash uses a fixed arc. No Flutter/Dart SDK is installed here; analyzer/tests and phone preview checks are pending.
- **Release gate:** Run `flutter analyze` and `flutter test`, then verify the selected slash in Skill Demo, arena and replay before release. This is not yet release-ready.

## RC analyzer and test-log repair (2026-11-03)
- Fixed nullable `SkillDefinition?` passed to muzzle resolver by pattern-matching a non-null draft skill before resolution.
- Replaced deprecated `withOpacity` with `withValues(alpha: ...)` in the area preview.
- Added braces to the grip attachment dropdown's conditional state update.
- Fixed a real regression-test failure: `copyWith(heldOffsetY: 0)` passed an integer into a `double?` field at runtime. Test now uses `0.0`.
- User log `1.14.44RC.log` ended at 1484 passed, 1 skipped, 8 failures: 7 suite-load failures from the nullable compilation error, and 1 independent GripValues regression-test type failure.
- Fixes were inspected in source and packaged; Flutter analyzer and tests still require rerun on user's Windows Flutter SDK.
- Cumulative source ZIP includes all v1.14.44 preview/slash source and new test files from the local development tree. No full project.

## RC repair 02: widget test regressions (2026-11-03)
- Reviewed 1.14.44RC(1).log: 1557 passed, 1 skipped, 8 failed. Seven editor tests report pumpAndSettle timeouts, and the grip dialog reports a 5px horizontal RenderFlex overflow.
- AnimatedEffectPlacementPreview now starts paused, with explicit Play/Pause and Step controls retained. This removes the unconditional repeating ticker from editor screens and permits widget tests to settle.
- Updated animated placement widget test to verify initial pumpAndSettle and paused settling after playback.
- Grip dialog projectile/impact comparison row now uses Expanded children and wrapped captions, avoiding intrinsic-width overflow in narrow dialogs.
- Source changes inspected; Flutter/Dart SDK unavailable here. Await user analyzer/test results. Not release-ready.

## RC repair 03: final grip dialog widget test (2026-11-04)
- User's `1.14.44RC(2).log` reports 1,564 passed, 1 skipped, 1 failed; `flutter analyze` reported no issues.
- The only failure was `grip preview edits forward/back, sideways and rotation live`: `tester.tap` attempted to hit Cancel at y=1583 outside the 1200x1000 test viewport. The dialog's scrollable content places action buttons below the viewport; this was a test interaction error, not evidence that Cancel itself fails.
- Updated the existing test to `ensureVisible` and settle before tapping both Cancel and Done, retaining assertions for discard and save behavior.
- No runtime UI code or gameplay behavior changed in repair 03. Flutter tests still need a rerun on user's Windows SDK. Do not mark release-ready before that run and phone verification.


## RC repair 04: Facing dropdown test visibility (2026-11-04)
- User's `1.14.44RC(3).log` reports 1,564 passed, 1 skipped, 1 failed. The sole failure remains the grip preview integration test, now at the Facing dropdown: test tap coordinates (650, 1525) were outside the 1200x1000 viewport, so the popup never opened and the subsequent `Stay upright` finder had no element.
- In `skill_management_screen_test.dart`, call `tester.ensureVisible` on `grip-preview-facing` and `pumpAndSettle` before opening the dropdown, then assert the popup item exists before selecting it. Previous Cancel/Done visibility fixes remain intact.
- No production runtime code changed in repair 04. Flutter SDK unavailable in this environment, so this fix is **not yet Flutter-verified**. Await targeted test, full suite and device acceptance before marking release-ready.
