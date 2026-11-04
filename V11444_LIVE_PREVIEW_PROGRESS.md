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

## Post-release v1.14.45 candidate: Sword Slash and pinned grip preview (2026-11-04)

### Implemented in this candidate
- **Sword melee Slash/Thrust now animates:** On physical blade contact, preserve a visual-only snapshot of the consumed weapon's kind, original slot, skill identity and 30-step lifetime if its animation is Slash or Thrust. The weapon itself is still removed immediately; the visual cannot attack, collide, be equipped or trigger damage. The snapshot expires after 30 `PowerUpSystem.step()` calls and is cleared on respawn. Legacy/null and None animations retain their previous behavior.
- **Existing Sprite fallback:** A configured slash without usable held sprite draws a moving slash/glyph fallback rather than a static badge during the attack.
- **Rendering identity:** The arena renderer uses snapshot skill ID for the temporary attack, preventing a newly equipped weapon from taking over the original sprite selection and grip parameters. Primary/secondary pose is preserved.
- **Pinned Grip Preview:** The dual-orientation weapon preview remains in the fixed top region; only sliders, dropdowns and other settings scroll below it, in a height-constrained dialog. Live state updates are still shared.
- **Regression tests added:** New `melee_attack_visual_test.dart` exercises consumption, single-hit semantics, countdown expiration, Slash/Thrust, legacy behavior and secondary slot. `grip_live_preview_values_test.dart` gains a widget test for preview position staying fixed after scrolling to Facing.

### Verification status
- **Implemented:** source edits plus regression tests authored.
- **Static packaging:** cumulative ZIP file list, SHA-256 content verification and ZIP CRC checks passed.
- **Flutter analysis/tests:** **NOT RUN** in this environment: no Flutter/Dart SDK is installed. The 1,565 passing tests are from the previous, unmodified v1.14.44 build; do not attribute them to this patch.
- **Release:** NOT release-ready until user reruns analyzer, focused tests, full suite and phone checks.

### Apply on Windows
1. Back up or commit the existing v1.14.44 working tree. Extract this ZIP at your project root (`D:\Development\ballwars`), preserving relative paths. The ZIP is a cumulative **changes-only** patch, not a complete Flutter project.
2. Run `flutter analyze`.
3. Run `flutter test test/features/arena_simulation/application/melee_attack_visual_test.dart test/features/skills/grip_live_preview_values_test.dart test/features/skills/skill_management_screen_test.dart --reporter expanded`.
4. Run `flutter test --reporter expanded`.
5. On phone: set built-in Sword held attack to Slash/Swing; save; hit target in Arsenal/All-Out; confirm sword vanishes from inventory immediately yet visibly swings after contact; check dual wield and a replacement pickup; adjust bottom grip sliders while preview stays visible.
6. Only after green gates, create a unique commit and tag `v1.14.45` on the existing **master** branch, and use existing release workflows.

### Out of scope
- No new weapon mechanics, timing customization or persistent configuration migrations.
- No new rendered image asset required.


## v1.14.46 RC: Configurable Held Attack Repeat Count (2026-11-04)

### Implemented
- New **Attack repeats (visual only)** dropdown (1–5, default 1) beside Held attack animation in Skill Editor and inside Grip Preview; the pinned preview shows the same configured repeat motion.
- `heldAttackRepeatCount` persisted as `held_attack_repeat_count` in skill JSON, with omitted defaults for backwards-compatible saves and clamping to 1–5 on parsing/copying. Existing skill configs default to exactly 1; no save migration needed.
- For a **single Slash**, the sprite now advances through one continuous forward arc and disappears at the end of the 30-step visual, rather than returning across the target. For a **single Thrust**, the sprite extends once and disappears instead of retracting and looking like a second strike. Counts 2–5 split the fixed cosmetic 30-step window into that many cycles.
- Non-sprite fallback now animates both Slash and Thrust. The legacy/null and None paths are unaffected.
- Repeat count is read by the real arena painter using skill identity and by Grip Preview. It does not change collisions, weapon consumption, damage, hit count, skill activation, attack rate, or the 30-step lifetime.
- Regression tests added for JSON persistence/clamping, legacy default, grip value persistence and repeat-cycle monotonicity/count.

### Gates and status
- Implemented: YES.
- ZIP integrity and SHA-256 contents: VERIFIED.
- Flutter analyze / tests: **NOT RUN HERE** (Flutter/Dart SDK unavailable). Previous user pass of 1,570 tests covers v1.14.45, NOT these new changes.
- Release status: NOT READY until user validates analysis, focused suite and full tests plus phone observation.

### Apply on Windows
1. Commit or back up your existing v1.14.45 code; extract this **cumulative changes-only** ZIP at `D:\Development\ballwars` preserving paths. No need to apply earlier RC44/45 ZIPs as well.
2. `flutter analyze`
3. `flutter test test/features/skills/held_attack_animation_test.dart test/features/skills/held_attack_motion_test.dart test/features/skills/skill_management_screen_test.dart test/features/skills/grip_live_preview_values_test.dart --reporter expanded`
4. `flutter test --reporter expanded`
5. On the phone, edit Sword → Held attack animation: Slash/Swing → Attack repeats: **1**, save and confirm one visual swing per Sword contact; also verify Thrust, repeat count 2/3, persistence after reopening the editor, and a settings slider while pinned Grip Preview stays visible.
6. Release **v1.14.46** only after green checks. The repository release branch is **master**, not main.

### Known behavior
- Total animation visual lifetime remains 30 simulation steps. Higher repeat counts use faster cycles within the same duration; this setting is cosmetic and not a multi-hit attack setting.


## v1.14.47 — Browser Admin Remember Me (2026-11-04)

**Baseline:** v1.14.46 confirmed installed and device-tested by the user; latest reported full test result for baseline: 1,573 passed, 1 skipped, 0 failed. This patch contains all v1.14.46 cumulative changes plus the v1.14.47 authentication changes. It is NOT yet Flutter-verified or released.

### Implemented
- The Admin sign-in dialog now offers an enabled Remember me checkbox in browsers, with opt-in default off and a trusted-device warning.
- SupabaseAdminAuth reads and writes the same `admin-remember-me` and `admin-session` DevicePrefs keys on browser and native platforms; the browser's existing PersistentPreferencesStore stores `pref:` keys in localStorage.
- On page load, a remembered admin session is recovered before the auth-state listener is subscribed, preventing an initial signed-out event from erasing it.
- Only local, nonanonymous admin-client auth events persist the admin session; device-client broadcast events cannot overwrite or clear saved admin credentials. The existing DeviceSessionGuard remains in place to protect the device's anonymous identity.
- Signing out or opting out clears remembered credentials. A definitely rejected saved session (HTTP 400/401/403) clears the remembered selection and token; transient network failures do not erase the saved token.
- Added session persistence policy tests and a widget assertion that the checkbox is enabled and unchecked by default.

### Security / functional limits
- Remember me stores an admin refresh token in browser-origin localStorage, accessible to scripts running on the same origin. Use only on a trusted browser/device, with strong XSS defenses and HTTPS. Browser private mode, blocked localStorage, or cleared site data may prevent persistence.
- Admin permission is still verified through `is_admin` on startup; an existing session is not automatically granted admin rights without server verification.
- GoTrue may broadcast authentication events across same-project clients/tabs. The policy protects durable tokens against cross-client broadcast events, but actual browser multi-tab interaction must be verified manually. Explicit sign-out in one tab does not necessarily synchronously sign out other open tabs.
- No schema migrations, credential changes, or Supabase project configuration changes are included.

### Regression / release checklist
- [x] Source changes implemented.
- [x] Cumulative ZIP integrity and member hash verification (packaging only).
- [ ] `flutter analyze` and `flutter test --reporter expanded` on the user's Flutter environment.
- [ ] Web: Remember me checked -> sign in -> reload -> close/reopen -> admin status retained.
- [ ] Web: Remember me unchecked -> sign in -> reload -> admin not retained.
- [ ] Web: Sign out -> reload -> admin still signed out.
- [ ] Web: Device groups/identity preserved after admin sign-in, refresh, sign-out.
- [ ] Web: session expiration/offline/reconnect and two-tab behavior.
- [ ] Android regression and GitHub release.

### Deployment
Extract the ZIP into the root of the Ball Wars repo, preserving paths and overwriting included files only. The ZIP is cumulative from the RC44 patch series through v1.14.47, not a full project archive. Run `dart format` on the modified Dart files, `flutter analyze` and the full test suite before committing or tagging. Treat v1.14.47 as an unreleased RC until browser behavior and tests are verified. Animation polish remains planned for v1.14.48.


## v1.14.48 RC — Polished Slash/Thrust motion and editable visual duration (2026-11-04)

**Input source:** v1.14.47 browser-admin cumulative ZIP. v1.14.47 test pass reported by user; its GitHub release/real-browser persistence confirmation was not supplied in this conversation. This ZIP includes all prior cumulative files plus v1.14.48 changes.

### Implemented
- One shared normalized visual-only pose for sprite and no-sprite fallback. Slash now has reverse anticipation, eased accelerating swing, lateral arc and subtle follow-through. Thrust has a wind-up and forward reach with easing and settle, rather than a rigid linear sprite slide.
- Repeats 1–5 retained, with exactly one forward strike per cycle. Reset between cycles is visual only.
- Configurable held melee animation lifetime **12–90 simulation steps**, default 30. Persisted as `held_attack_duration_steps`, omitted from JSON for legacy default. The persisted setting is available in both Skill Editor and Grip Preview; animation-frame preview uses the chosen duration.
- The consumed melee weapon's transient artwork snapshots the configured lifetime. Equipped weapon / projectile firing lifetime remains 30 steps to avoid changing mechanical firing cadence.
- Damage, projectile timing, equipment consumption, and contact logic are otherwise unchanged. No new assets required.
- Regression tests added for anticipation, eased thrust and swing poses, duration persistence/clamping and visual expiry with no extra hit.

### Release gate / roadmap
- [x] v1.14.48 source patch implemented.
- [x] ZIP structure, SHA-256 manifest and archive CRC verified.
- [ ] Flutter SDK unavailable in this environment; run `dart format` on changed Dart files, `flutter analyze`, `flutter test --reporter expanded` locally.
- [ ] Browser/phone: verify Sword slash/thrust 1/2/3 repeats and visual durations 12/30/60, preview matches arena, grip positioning and screenshot visuals.
- [ ] Validate v1.14.47 browser Remember Me in the deployed app, if not already done.
- [ ] Commit/push to repository `master`; create v1.14.48 tag and deploy only after checks.

### Deployment
Extract cumulative ZIP at the repository root, overwriting matching relative paths. Do **not** replace the whole project; the ZIP contains only cumulative changed files, tests, progress report and SHA-256 manifest. Run `dart format` on changed Dart files before the analyzer/tests, review the diff for unrelated files, then commit and tag only after both automated and device checks pass.


## v1.14.48 RC Repair 01 — phone attack-duration dropdown

- **Root cause:** The new `skill-held-attack-duration` `DropdownButtonFormField<int>` exceeded its fixed-row control's width at 360 px, producing an 8.3 px `RenderFlex` overflow in the Shotgun phone-layout regression. Subsequent widget-inspector ancestor errors are secondary to the layout exception.
- **Fix:** Set `isExpanded: true` on the duration dropdown so its selected item is constrained to the available horizontal width while preserving its `12–90 steps` values and save behavior.
- **Regression:** `attack duration dropdown fits a 360 px phone` tests the formerly overflowing control in the phone editor. The original `phone subtab drafts, decimal steppers and linked shell counts survive save and reopen` also remains intact.
- **Verification:** Code change and ZIP SHA-256/integrity verified. **Flutter tests not run in the patch environment**; the user should run analyzer, focused widget test and full suite on their Flutter installation.
- **Release gate:** Do not tag/release v1.14.48 until all Flutter tests and device visual checks pass.
- **Apply:** Extract this changes-only cumulative ZIP into the v1.14.47 project root, replacing the included paths. Review `git diff`, run `flutter analyze`, then `flutter test test/features/skills/skill_management_screen_test.dart --reporter expanded` followed by `flutter test --reporter expanded`.


## v1.14.48 RC Repair 02 — phone regression test navigation

- **User test result after Repair 01:** 1,579 passed, 1 skipped, 1 failed. The existing Shotgun phone-layout save/reopen regression now passes. Only the newly added `attack duration dropdown fits a 360 px phone` test fails.
- **Cause:** The new test searched for Sword and tapped a `ListTile` at y=732, but the hit test landed on the page overlay/bottom navigation. The Sword editor never opened, causing `_revealEditor` to report a missing duration control. This is not a new overflow.
- **Fix:** The duration regression now opens the Shotgun editor through the same verified phone-width navigation used by the existing passing Shotgun test. An explicit hit-test assertion confirms the tile is tappable before tapping. It then reveals the Attack Duration dropdown and checks for layout exceptions. The `isExpanded: true` production UI fix from Repair 01 is unchanged.
- **Implemented:** Regression navigation fix; cumulative ZIP and SHA-256 manifest rebuilt and checked.
- **Tested:** User reported 1,579 passing tests from Repair 01; Repair 02 has not been run under Flutter in this environment.
- **Release readiness:** Pending focused test, full suite, and visual/device confirmation. Do not tag/release yet.
- **Apply:** Extract this cumulative ZIP into the project root. Run `flutter analyze`, `flutter test test/features/skills/skill_management_screen_test.dart --reporter expanded`, then `flutter test --reporter expanded`.


## v1.14.49 RC — Arena Pickup Preview and Skill Demo UX (2026-11-04)

### Audit of existing functionality
- The pre-existing Skill Demo already used the actual `FieldPowerUp` collection, live `ArenaCanvas` / `PowerUpPainter` path, a spawn/clear pair, and artwork focus chips. This work improves their usability rather than duplicating those implementations.

### Implemented
- Pinned the real arena canvas **outside** the vertically scrolling inspector/settings. The arena stays on-screen while distance, arena shape, artwork modes and settings scroll independently. It continues drawing actual pickup scale through the same game renderer and draft SkillLibrary.
- Moved Spawn pickup/Clear pickup next to the Casting, Equipped, Projectile, Impact and Pickup focus controls. The existing spawn location remains near the top of the real isolated arena and can be cleared/reset without mutating a live match.
- Added per-artwork **Edit settings** icon shortcuts alongside each of the five focus chips, returning the correct role to the existing Skill Editor routing (Pickup/Equipped to Appearance, Projectile and Impact to corresponding artwork subsections).
- Added a visible effective pickup size multiplier, respecting the existing global/per-skill pickup-size policy from SkillLibrary. No independent scale approximation is used in the arena renderer.
- Added widget regression coverage for a 360x800 viewport (arena remains at fixed screen coordinates after scrolling, spawn succeeds without layout exceptions) and editor-role shortcut navigation.

### Verification and release readiness
- [x] Existing demo and renderer behavior inspected; implementation written.
- [x] Cumulative changes-only ZIP checked (CRC and SHA-256 manifest).
- [ ] Dart formatter and Flutter analyzer are unavailable in this environment. Run them on your Windows Flutter SDK.
- [ ] Run targeted `flutter test test/features/skills/skill_demo_test.dart --reporter expanded`, then full `flutter test --reporter expanded`.
- [ ] Browser and phone: scroll settings while stage stays visible, spawn/clear pickup, compare actual size and colors against match, test every focus/edit shortcut, verify custom skill draft.
- [ ] Release only after automated and on-device verification. Existing v1.14.48's 1,580 passing tests do not verify this new code.

### Apply and deploy
Extract the ZIP at the project root, replacing included files only. It includes the complete RC44–RC48 cumulative patch series plus v1.14.49 changes, tests, report and manifest; it is **not** a full-project archive. Format modified Dart files, review diffs, analyze/test and create the release tag only after the checks pass.


## v1.14.49 RC Repair 01: Held Attack VFX, discoverable controls, flipped facing (2026-11-04)

### Implemented (source inspection only)
- Relocated Held Attack Animation (Slash / Swing, Thrust, None, repeats 1-5 and visual duration 12-90 steps) from Mechanics to Appearance > Held & pickup, immediately before the artwork slots. Maintained original widget keys for compatibility.
- Added a **Held Attack VFX** sprite selection row, independent of Direct Hit Effects (impact sprite). It stores a separate optional sprite ID in `held_attack_vfx_sprite` and preserves null/missing-artwork fallback.
- The arena painter and Grip Preview use the same Held Attack VFX binding. Animated frames follow each configured attack repeat phase, current weapon pose, grip offsets, facing direction and held-attachment side(s). The visual effect is cosmetic only, leaving impact effects and damage unchanged.
- Corrected slash rotation to mirror around the left-facing ball; a flipped sword no longer starts its swing below the ball. Applied to both real-sprite and glyph fallback paths, including temporary melee-attack visuals.
- Added persistence/regression tests for the independent VFX slot, left/right and secondary-hand facing poses, actual rendering of registered VFX only during attack, and presence of the control on 360-pixel phone editor layout.

### Verified / release readiness
- Original v1.14.49 RC: user-reported 1,582 passed, 1 skipped, 0 failed BEFORE this repair. These results do not verify this repair.
- This cumulative changes-only ZIP includes all previous v1.14.49 source changes and tests; ZIP CRC and SHA-256 of packaged entries are checked.
- No Flutter/Dart SDK installed here. `flutter analyze` and `flutter test` on this repair are **NOT RUN**. Phone/browser preview also not verified.
- Release **BLOCKED** pending user Flutter analysis, focused and full tests, and live right/left Sword swing preview.

### Deployment / verification
Extract ZIP over the source tree of Ball Wars v1.14.48 / v1.14.49 RC, preserving relative paths. Do not use it as a complete project. Run:

```powershell
dart format lib/features/skills/domain/skill_library.dart lib/features/skills/presentation/skill_management_screen.dart lib/features/skills/presentation/grip_preview_dialog.dart lib/features/arena_simulation/presentation/arena_painter.dart lib/features/arena_simulation/presentation/power_up_painter.dart test/features/skills/held_attack_animation_test.dart test/features/skills/held_attack_motion_test.dart test/features/skills/held_attack_vfx_test.dart test/features/skills/skill_management_screen_test.dart
flutter analyze
flutter test test/features/skills/held_attack_vfx_test.dart test/features/skills/held_attack_animation_test.dart test/features/skills/held_attack_motion_test.dart test/features/skills/skill_management_screen_test.dart --reporter expanded
flutter test --reporter expanded
```

Inspect Sprite Picker > Animated, choose a 4-frame slash effect, enable Slash / Swing, and preview from both directions. Direct Hit Effects must remain independent.
