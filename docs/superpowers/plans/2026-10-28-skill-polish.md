# Skill Polish (grip range, push-to-all, gun shells, built-in descriptions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four small skill-management improvements the owner asked for on 2026-10-28, after testing v1.14.23.

**Architecture:** All four live in `SkillDefinition` / `SkillLibrary` (`lib/features/skills/domain/skill_library.dart`), the Skill Management editor, and the painters that read a skill's settings. No simulation behavior changes: shells are cosmetic, descriptions are text, grip is drawing, push-to-all only rewrites stored values.

**Spec:** The owner's requests (2026-10-28), quoted per task, plus these answers: push-to-all covers callout duration, screen shake and the three sprite size scales; shells: today's four guns keep dropping shells and every gun skill gets a Shell setting; built-in behavior stays coded (Duplicate into a custom skill is the way to edit behavior).

## Global Constraints

- Determinism: nothing here may add or remove an RNG draw. Randomness in casings must come from a pure hash (for example of the casing's sequence number), never `_rng`, and never per rendered frame.
- Replay snapshots (`skills=`) have a size limit (`SkillLibrary.maxReplayCharacters`, 48000). New fields are written only when they differ from their default (as `melee_reach`, `rarity` and `description` are).
- Painting performance: no blur, no per-frame Paint or list allocation in hot paths (cache Paints; see CLAUDE.md).
- UI text plain `-`, no en/em dashes. Dialogs and new sheets at most 440 px wide. Web-safe (no `dart:io` in `lib/`).
- Skill Management is admin-only already; nothing here adds a player-facing control.
- Format only the files you touch. Update CLAUDE.md where behavior is documented.

## Review Focus

- "Apply to all" on a library with every built-in overridden must still encode into a replay snapshot (the 48000 limit): measure it and handle it.
- A gun with a shell sprite id that no longer exists (renamed sheet, removed custom sprite) must fall back to the brass vector shell, never crash or draw nothing.
- Negative grip forward/back must still draw the hands and the weapon consistently when the ball faces left (mirror) and in dual wield.
- A built-in description override must be cleared by "Restore defaults", like other fields.

---

### Task 1: Grip forward/back can push the weapon out

Owner: "inset is gone? I can use this to position the hilt of the sword to the hand (a way to move the sprite left/right and up/down), include this to the grip preview."

Facts from the code: nothing was removed. The old "Grip inset" is now "Grip forward/back", next to "Grip sideways" and "Grip rotation", plus "Preview grip" (Skill editor > Appearance, weapons only). Forward/back is limited to 0..1.5, so it can only pull the weapon toward the ball; the sword cannot be pushed outward to put its hilt in the hand.

**Files:** `skill_library.dart` (`validated()` clamp, about l.663), `skill_management_screen.dart` (limits about l.1536, labels and help about l.2723-2750), `power_up_painter.dart` (`heldCenter`: the inset clamp 0..1.5 and `max(0.1, base - inset)`), `grip_preview_dialog.dart`; tests `held_grip_painter_test.dart`, `skill_library_test.dart`, `skill_management_screen_test.dart`.

- [ ] **Step 1: Failing tests**: `weaponGripInset` accepts -1.5..1.5 (JSON round trip and clamp at both ends); `heldCenter` with inset -0.5 puts the weapon 0.5 radii farther from the ball than inset 0 along the aim, mirrored correctly facing left and for slot 1; values 0..1.5 draw exactly as before.
- [ ] **Step 2: Implement**: widen the clamp in `validated()`, the editor limit and `heldCenter` (keep a minimum distance so the weapon never reaches the ball center: at least 0.1 radii as today). Help text: "Forward/back: positive pulls the weapon toward the ball, negative pushes it out."
- [ ] **Step 3: Preview**: in `GripPreviewDialog` draw a small crosshair marker at the ball's hand position (where `paintHands` puts the grip hand) in both views, so the hilt can be lined up with it while the three sliders move; nothing else changes. Test the marker is drawn (pixel check) and the dialog still returns the three values.
- [ ] **Step 4: Run** focused then full tests. **Commit** `feat: grip forward/back can push the weapon out, hand marker in the preview`.

### Task 2: Apply a Global value to every skill

Owner: "Skill mgmt, General, sprite arena size, we have a 'Let each skill sets its own', what if I want to set a value to all of it (push values to all that actually modifies each)? all we have here is an override, that's different."

**Files:** `skill_library.dart` (new `SkillLibrary.applyToAll`), `skill_management_screen.dart` (Global tab `_globalCard`, about l.629-800; add cards for the three size scales), tests `skill_global_settings_test.dart`, `skill_management_screen_test.dart`.

**Interfaces:** `SkillLibrary applyToAll(PowerUpConfig tuning, {double? calloutSeconds, double? screenShake, double? weaponDisplayScale, double? pickupDisplayScale, double? effectDisplayScale})` returns a library in which every skill (built-ins through an override, custom skills in place) has the given own values; null leaves a field alone.

- [ ] **Step 1: Failing tests**: after `applyToAll(calloutSeconds: 3)` every skill's own callout is 3 (built-ins resolve through `builtIn(kind, tuning)` to 3, custom skills too) and other fields are untouched; applying to a library that already has some overrides keeps their other edits; `applyToAll` with no arguments is a no-op (same library).
- [ ] **Step 2: Replay size check (Review Focus)**: build a library with all 49 built-ins overridden plus 10 custom skills and call `encodeReplay`. If it fails or exceeds about 30000 characters, change override serialization to store only the fields that differ from the built-in default (backward compatible: reading a full override still works, and the JSON of a library with no changes stays identical to today), with tests that old full-override JSON and links still decode to the same library. If it stays small, add only a test that pins the measured size.
- [ ] **Step 3: UI**: the Global tab gets one card per value: callout duration and screen shake (existing) and Equipped / Pickup / Effect artwork size (new, 0.25..3, default 1, with "Let each skill set its own" like the existing two, stored the same way). Each card has an **Apply to all skills** button; it asks for confirmation ("Set <value> on all N skills? This changes each skill's own value."), then calls `applyToAll`, updates the editor state and shows a SnackBar; the change is saved with Save library like everything else. The override toggle keeps working as before.
- [ ] **Step 4: Run** focused then full tests. **Commit** `feat: apply a global value to every skill`; CLAUDE.md (Global skill settings).

### Task 3: Gun shell settings

Owner: "gatlings shell in the arena, can we have an admin-only setting for this, to make it bigger and adjust its sprite? ... guns should all have this parameter, so maybe in the skill mgmt? A shell parameter that will hold sprite used, and size, and a control random orientation when dropped on the bottom of the arena."

Facts from the code: casings already exist (`ShellCasing`, `PowerUpSystem._ejectShellCasing`, at most 80; ejected by Pistol, Shotgun, Gatling and Freeze; drawn as a small brass rectangle in `PowerUpPainter` about l.1007; they spin while falling and rest where they land).

**Files:** `skill_library.dart` (new fields), `power_up.dart` (`ShellCasing` gets `spriteId`, `size`, `randomRest`), `power_up_system.dart` (`_ejectShellCasing`, `_updateShellCasings`), `power_up_painter.dart` (casing drawing), `skill_management_screen.dart` (Appearance tab, gun skills), tests.

**Interfaces:** `SkillDefinition.shellEnabled` (bool?, null = default by kind: true for pistol, shotgun, gatling and freeze, false for other guns; JSON `shell`, written only when non-null), `shellSprite` (String?, a `SpriteRegistry` id, null = brass vector shell; JSON `shell_sprite`), `shellSize` (double, 0.25..4 times today's size, default 1; JSON `shell_size`), `shellRandomRest` (bool, default true; JSON `shell_random_rest`, written only when false).

- [ ] **Step 1: Failing tests**: JSON round trips and defaults (old JSON behaves as today); the four default kinds eject, another gun does not until `shellEnabled: true`, and `shellEnabled: false` stops the default four; a casing created by a skill carries that skill's sprite, size and rest settings; with `shellRandomRest` the resting angle differs between casings of one match and is identical across two runs of the same seed (pure hash of the casing's sequence number, no `_rng` draws: assert the controller's RNG position after N shots is identical with the feature on and off); with `shellRandomRest: false` the resting angle is the spin angle at impact as today; defaults render the same pixels as before; an unknown `shellSprite` id falls back to the brass shell.
- [ ] **Step 2: Implement** the fields (copyWith, toJson written only when non-default, fromJson, `validated()` clamps, `_same` through toJson); the eject decision `shellEnabled ?? kind is one of the four`; casing creation with the skill's settings; resting angle from a pure integer hash of the casing's sequence number (web-safe: mask to 31 bits like `HairStyles.hashOf`); painter: sprite through `SpriteRegistry.frame(id)` drawn nearest-neighbor and centered, size scaled by `shellSize` times today's dimensions, cached Paints.
- [ ] **Step 3: Editor**: in the Appearance tab for gun skills, a "Shell" group: Drops shells (Default / On / Off), Shell sprite (dropdown: "Brass shell (default)" plus the registry's bundled projectile and effect sprites and any `custom.*` ones, with a small preview), Shell size slider, Random rest orientation switch; all included in "Restore defaults". Admin-only like the rest of Skill Management.
- [ ] **Step 4: Run** focused tests, `flutter test tool/bench/paint_bench_test.dart` (no slowdown), then the full suite. **Commit** `feat: per-gun shell settings (drop, sprite, size, random rest)`; CLAUDE.md.

### Task 4: Edit built-in skill descriptions

Owner: "expose skill description to admin like what you did in custom skills, maybe I want to edit it."

**Files:** `skill_library.dart` (`validated()` currently drops `description` for built-ins), `skill_management_screen.dart` (Identity tab: the Description field is shown for custom skills only, about l.2044; list subtitle about l.379), `match_setup_screen.dart` (the built-in card uses `powerUpDescription`, about l.1960-2020), `power_up_test_screen.dart` if it shows descriptions; tests `skill_library_test.dart`, `skill_management_screen_test.dart`, `match_setup_packs_test.dart`.

- [ ] **Step 1: Failing tests**: a built-in override with a description round-trips JSON and is kept by `validated()`; the Weapons dialog built-in card shows the override text, else the generated `powerUpDescription`; Restore defaults clears it; the editor shows the Description field for built-ins and saves it; custom skill behavior is unchanged.
- [ ] **Step 2: Implement**: keep `description` for built-ins (same `cleanDescription`, 160 characters cut on characters), show the field for every skill, use the override in the Weapons dialog, the Skill Management list and any other place a built-in's description is shown (grep `powerUpDescription(`); an empty field means "use the generated text".
- [ ] **Step 3: Run** focused then full tests. **Commit** `feat: editable descriptions for built-in skills`; CLAUDE.md.
