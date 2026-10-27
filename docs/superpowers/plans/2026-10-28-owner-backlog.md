# Owner Backlog (7 features) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the owner's seven requests: end-endless button, arena picker in the Power-up test, HP bars above balls, grip x/y/rotation with a preview, melee reach, the Shadow Clone special skill, and ball gender with female hair styles.

**Architecture:** Each task is independent and touches its own area: controller + battle screen + links (T1), power-up test screen (T2), ArenaPainter + Match Setup (T3), SkillDefinition + PowerUpPainter + skill editor (T4), PowerUpSystem melee (T5), a new PowerUpKind (T6), CustomBall + group storage + hair painter (T7). Code map with line numbers: the scratch file `feature-map.md` summarized below in each task.

**Tech Stack:** Flutter/Dart, CustomPainter, Supabase (one new migration), flutter_test.

**Spec:** No separate spec doc. The owner's requests (2026-10-28) and answers are the spec:
- "user settings, show hp at the top of head, moves with the ball" + answer: **thin bar**.
- "special skill kage bunshin no jutsu ... cast, instacast when picked up" + answer: **a special skill like Raging Demon / Energy Wave; creates 3 shadow clones and then all of them attack one by one, each causing a configurable 5 damage**.
- "grip inset, adjustable in x and y? And a quick preview with the ball holding it, this can be a small pop up. Also a way to adjust rotation."
- "skill reach, melee and range" + answer: **add a melee reach value**.
- "ball gender, when creating/editing a ball, add a gender selection ... female hair style" + answer: **hair shows in both looks** (faces and pictures).
- "when endless battle is selected, put a button next to unstuck to end the battle, not right away but after a ball is defeated, and then doing the usual flow, finisher if on, winning screen, and tally."
- "powerup test, add a change arena button, clicking will show the arenas with preview ... at the bottom bar".

## Global Constraints

- Determinism: all simulation randomness from the match's `SeededRandom`, drawn only inside steps; never in painters. A new feature must not change the RNG draw sequence of matches that don't use it (the Threads 40-result pin and existing replays must still pass).
- Anything a user does mid-match that changes the outcome is recorded by step and carried in replay links and the video export (like `nudge=`).
- `PowerUpKind` entries are appended LAST (links store chosen kinds as a bitmask of the index).
- UI text never uses en or em dashes; plain `-`.
- New screens/dialogs are at most 440 px wide on wide screens (wrap like SettingsScreen).
- Web-safe: no `dart:io` in `lib/`. Images as bytes.
- Painting performance: no blur filters, no per-frame string building or allocation in hot paint paths (see CLAUDE.md "Painting performance").
- No AI image generation. Hair and the clone icon are drawn in code (like the existing `BallHairPainter` and `power_up_pixel_art.dart`); raster edits, if any, only with PhotoCraft.
- Supabase: new columns via a new migration `022_*.sql` with `add column if not exists`; the app keeps working before it is run (query new columns separately or tolerate their absence, as migration 008 columns are).
- Each task updates CLAUDE.md where it changes documented behavior.

## Review Focus

- A replay link or video of an endless battle that was ended with the new button must replay to the same winner (the end request is recorded by step).
- HP bars in Mayhem with 6 small balls must stay readable and not overlap callouts; life above 100 (apples) shows the gold overflow.
- A skill with melee reach 0 (every built-in default) must behave exactly as today: same hits, same RNG draws, same match outcomes.
- Shadow Clone when no opponent is alive, or the target dies after the first clone hit: remaining clones end cleanly, no crash, the owner returns to its spot.
- A ball saved with a gender before migration 022 is run: saving must not fail; gender silently stays None.

---

### Task 1: End an endless battle after the next defeat

**Files:**
- Modify: `lib/features/arena_simulation/application/match_simulation_controller.dart` (elimination step ~l.951-984, `_finishMayhem` ~l.690-711, `requestNudge` ~l.239 as the model)
- Modify: `lib/features/arena_simulation/presentation/arena_battle_screen.dart` (Unstuck button ~l.827-843; `_initMatch`, `_replay`)
- Modify: `lib/features/replay_export/domain/replay_link.dart`, `lib/app.dart`, `lib/features/replay_export/application/replay_video_exporter.dart`, `lib/features/replay_export/presentation/export_video_dialog.dart`
- Test: `test/features/arena_simulation/application/match_modes_test.dart` (or new `end_endless_test.dart`), `arena_battle_screen_test.dart`, `replay_link_test.dart`

**Interfaces:**
- Produces: `void MatchSimulationController.requestEndAfterKnockout()`, `bool get endRequested`, `int? get endStep` (the step at which it was requested), ctor param `int? endAfterKnockoutStep`; replay link `end=<step>`; `ArenaBattleScreen(endStep:)`.

- [ ] **Step 1: Failing tests**: `ending an endless battle waits for the next knockout`: endless Arsenal, seed fixed, call `requestEndAfterKnockout()`; before any elimination status stays running; at the first elimination after the request the defeated ball does not respawn, `status == finished`, `lastEliminatedId` is the defeated ball, `winnerId` is the tally leader (eliminations desc, then fewer deaths, then life, same as `_finishMayhem`), `winningMove` is the move that defeated it. `replaying with endAfterKnockoutStep reproduces the winner`: a second controller built with the recorded step ends identically. `the request is ignored outside endless battles and after finish`. Replay link round-trips `end=` (1..36000, rejected otherwise and without `endless=1`).
- [ ] **Step 2: Run** `flutter test test/features/arena_simulation/application/` : FAIL.
- [ ] **Step 3: Implement**: the request is applied at the next step boundary like nudges (record `endStep` = step index); in the elimination step, when `endlessBattle && endStep != null` and a ball is eliminated, skip respawn for it and finish using `_finishMayhem`'s ranking, keeping `lastEliminatedId` = the defeated ball and `winningMove = _lastMove[defeated]`. Mayhem keeps its own timer end. No RNG draws added.
- [ ] **Step 4: Screen**: in endless (not Mayhem) battles show `OutlinedButton.icon(key: ValueKey('arena-end-battle'), icon: Icons.flag_rounded, label: 'End battle')` right of Unstuck in the same bottom-left Row; after tapping it shows `Ending after next KO` and is disabled. The existing end flow (dissolve, finisher if on, WinnerModal with tally) runs unchanged. Replay passes the recorded step; links and the video export carry it.
- [ ] **Step 5: Run** focused tests then full `flutter test` : PASS.
- [ ] **Step 6: Commit** `feat: end an endless battle after the next knockout`; update CLAUDE.md (Unstuck paragraph + endless).

### Task 2: Change arena in the Power-up test

**Files:**
- Create: `lib/features/arena_simulation/presentation/arena_preview.dart`
- Modify: `lib/features/settings/presentation/power_up_test_screen.dart` (`_playback()` bottom bar ~l.1102-1169, `_reset()` ~l.181-228, `_arena()` ~l.658-768)
- Test: `test/features/settings/power_up_test_screen_test.dart`

**Interfaces:**
- Produces: `class ArenaPreview extends StatelessWidget { const ArenaPreview({required ArenaDecoration decoration, double size = 96}); }` painting the floor and rim of that arena (reuse ArenaPainter with an empty state, no balls, no RNG).

- [ ] **Step 1: Failing widget test**: tapping `test-arena` in the bottom bar opens a sheet with one `ArenaPreview` per `ArenaDecoration` (keys `test-arena-<name>`) and its label; picking Desert closes the sheet, resets the fight with `arenaDecoration: desert` (controller and painter) and the button shows the arena name; the choice is remembered under DevicePrefs `power-test-arena`.
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement** `ArenaPreview` and the bottom-bar button (`OutlinedButton.icon(key: ValueKey('test-arena'), icon: Icons.stadium_outlined, label: <arena label>)` in the playback Row); the sheet is a 440 px max-width grid. Default is the admin's arena when nothing is saved.
- [ ] **Step 4: Run** focused then full tests : PASS.
- [ ] **Step 5: Commit** `feat: change arena in the power-up test`.

### Task 3: HP bar above each ball

**Files:**
- Modify: `lib/features/arena_simulation/presentation/arena_painter.dart` (`_paintSingleBall` l.550-707 or a pass after all balls), `arena_canvas.dart`, `lib/features/match_setup/domain/match_config.dart`, `match_setup_screen.dart` (Appearance group ~l.1383-1496, `_loadPrefs`, `_start`), `arena_battle_screen.dart`, `replay_frame_painter.dart` (`ReplayStyle`), `export_video_dialog.dart`, `replay_video_exporter.dart`, `power_up_test_screen.dart` (on)
- Test: `test/features/arena_simulation/presentation/arena_painter_test.dart`, `match_settings_layout_test.dart` or `match_setup_packs_test.dart`

**Interfaces:**
- Produces: `MatchConfig.showHpBars` (bool, default false), ArenaPainter/ArenaCanvas `showHpBars`, `ReplayStyle.showHpBars`, profile pref `hp-bars`.

- [ ] **Step 1: Failing tests**: painter draws a bar for each alive ball centered above it at `ball.position.dy - ball.radius * 1.35`, width `ball.radius * 1.6`, height `max(3, ball.radius * 0.16)`; fill ratio = `life / arenaLife` (Arsenal, clamp 0..1) with a gold segment for life above 100 up to `arenaMaxLife`, `lineCount / startLines` (Threads and All-Out); green above 50%, amber above 25%, red below; none for eliminated balls; none when off. Match Setup Appearance has `HP bars` (Off/On, per match-type profile key `hp-bars`).
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement**: draw bars after all balls (so they're on top), with plain rects (no text, no allocation per frame beyond Paint reuse); thread the flag through ArenaCanvas, the battle screen, the Power-up test (on) and the video (`ReplayStyle`). Cosmetic: not in replay links.
- [ ] **Step 4: Run** focused then full tests; `flutter test tool/bench/paint_bench_test.dart` with bars on (record numbers in the commit).
- [ ] **Step 5: Commit** `feat: optional HP bar above each ball`; CLAUDE.md.

### Task 4: Grip offset and rotation with a preview

**Files:**
- Modify: `lib/features/skills/domain/skill_library.dart` (SkillDefinition fields, copyWith, toJson/fromJson, clamps, `_defaultFor`), `lib/features/arena_simulation/presentation/power_up_painter.dart` (`heldAngle` ~l.2198, `heldCenter` ~l.2223, `_paintHeldWeapon` ~l.3003), `ball_face_expression.dart` (`paintHands` ~l.181), `arena_painter.dart` (closures ~l.673-703), `lib/features/skills/presentation/skill_management_screen.dart` (Appearance tab ~l.2564-2575)
- Create: `lib/features/skills/presentation/grip_preview_dialog.dart`
- Test: `test/features/skills/skill_library_test.dart`, `test/features/arena_simulation/presentation/equipped_scale_render_test.dart`, `skill_management_screen_test.dart`

**Interfaces:**
- Produces: `SkillDefinition.weaponGripSide` (double, ball radii, -1.5..1.5, default 0; JSON `weapon_grip_side`) and `SkillDefinition.weaponGripRotation` (double, degrees, -180..180, default 0; JSON `weapon_grip_rotation`). Existing `weaponGripInset` stays the forward/back axis (label "Grip forward/back"); the new side value moves the weapon across the aim line (label "Grip sideways", mirrored for the second hand when dual wielding); rotation is added to the sprite angle (mirrored when the sprite flips).

- [ ] **Step 1: Failing tests**: JSON round trip and clamps for both fields; old JSON without them reads 0; `heldCenter` with side 0.5 moves the center by `0.5 * radius` perpendicular to the aim; the drawn sprite angle includes the rotation; hands follow the same center/angle; defaults leave every built-in drawing unchanged (equipped_scale_render goldens/asserts unchanged).
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement** fields, painter, hands. Editor: two new sliders under Grip, plus a `Preview grip` button (key `skill-grip-preview`) that opens `GripPreviewDialog` (max 440 px): a ball holding this skill's weapon painted with the real PowerUpPainter path, with the three grip sliders live; Done writes the values back to the editor fields, Cancel discards.
- [ ] **Step 4: Run** focused then full tests : PASS.
- [ ] **Step 5: Commit** `feat: grip sideways and rotation with a live preview`; CLAUDE.md.

### Task 5: Melee reach

**Files:**
- Modify: `skill_library.dart` (field, JSON, clamp, editor wiring), `power_up_system.dart` (`onContact` ~l.1299, `_melee` ~l.1329, `step()` ~l.372), `skill_management_screen.dart` (Damage & Timing tab for weapons whose trigger is collision, or built-in blades/flail/shield)
- Test: `test/features/arena_simulation/application/power_up_effects_test.dart` (or new `melee_reach_test.dart`), `skill_library_test.dart`

**Interfaces:**
- Produces: `SkillDefinition.meleeReach` (double, ball radii added to the contact distance, 0..3, default 0; JSON `melee_reach`; label "Melee reach").

- [ ] **Step 1: Failing tests**: with reach 0 nothing changes (an existing melee scenario gives identical hits and RNG draws: compare a recorded match result before/after); with a knife skill of reach 1.0, an opponent whose centers are `r1 + r2 + 0.9 * r1` apart takes the hit without touching (weapon consumed as today); a ghost is never hit by reach; reach never triggers twice for one weapon.
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement**: once per step in `PowerUpSystem.step()`, for each alive non-ghost ball in the match's fixed ball order holding a melee weapon (blade, orbiting flail, shield bash, or a composed collision skill) whose resolved skill has `meleeReach > 0`, find the nearest alive non-ghost opponent within `a.radius + b.radius + meleeReach * a.radius` and call `_melee` exactly as `onContact` would. No RNG draws. Editor shows "Melee reach" (ball radii) for those skills.
- [ ] **Step 4: Run** focused tests, the Threads pin and full `flutter test` : PASS.
- [ ] **Step 5: Commit** `feat: melee reach for contact weapons`; CLAUDE.md.

### Task 6: Shadow Clone special skill

**Files:** every registration point for a new `PowerUpKind` (model: Raging Demon):
- `lib/features/arena_simulation/domain/power_up.dart` (enum entry appended last `shadowClone('Shadow Clone')`, rarity special, power-up (instant), `impactWeight` 1.0, `PowerUpTuning.arenaDamage[shadowClone] = 5`, `allOutThreads[shadowClone] = 2`, `powerUpDescription`, `ShadowCloneAttack` state class)
- `power_up_config.dart` (`damageKinds` + field `shadowCloneCount` "Shadow clones" default 3, 1..6, integer, with getter)
- `power_up_system.dart` (state list, `pickUp` case, `_startShadowClone`, per-step update in `_updatePhaseEightAttacks` or its own, `resetForRespawn` cleanup)
- `power_up_painter.dart` (`_colors[shadowClone]`, overlay: clones drawn as darkened translucent copies of the owner's body (face or picture via the same painters) with a smoke puff when they appear and vanish)
- `power_up_pixel_art.dart` (16x16 icon: a ball with two shadow copies), `skill_library.dart` (`_defaultYellFor` "KAGE BUNSHIN NO JUTSU!", sound cue), `finisher_profile.dart` (profile keyed 'Shadow Clone'), `harpoon_cinematic.dart` (optional case; default style acceptable)
- Tests that pin kind counts (see list in the code map: finisher_gallery 48 -> 49, power_up_rarity_test, power_up_test, power_up_painter_test pixel-icon set, replay_link_test bitmask, skill_library_test, match_setup_packs_test, sprite goldens icon sheet (update with reason))
- Test: new `test/features/arena_simulation/application/shadow_clone_test.dart` modeled on `phase8_content_test.dart` (`_give(match, owner, kind)`)

**Interfaces:**
- Produces: `PowerUpKind.shadowClone`, `PowerUpConfig.shadowCloneCount`, `PowerUpSystem.shadowCloneAttacks` (list of `ShadowCloneAttack {owner, target, clones, age, clonesDone}`), tuning `dmg.shadowClone` default 5 (admin-editable in Settings > POWER-UPS like every damage value).

- [ ] **Step 1: Failing tests**: on pickup, the owner yells "KAGE BUNSHIN NO JUTSU!", time freezes for the sequence (like Raging Demon, `_freezeTime`), 3 clones appear around the owner; clone 1, 2, 3 each dash to the nearest alive opponent in turn and hit once through `_hit` for the configured damage (Arsenal 5 per hit by default; `dmg.shadowClone` changes it; All-Out cuts `lines.shadowClone` threads); `shadowCloneCount` changes the number; if the target dies the remaining clones retarget the next nearest or vanish if none; positions are pure functions of age (no RNG); same seed gives the same result; the kind appears in the Weapons dialog (Power-ups tab) and Skill Management with tier Special.
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement** the registration points above. Timing: clones appear over 12 steps, then one dash+hit every 14 steps, smoke-out 12 steps after the last hit.
- [ ] **Step 4: Run** focused tests, then full `flutter test` (update pinned counts and the icon golden with the reason in the commit).
- [ ] **Step 5: Commit** `feat: Shadow Clone special skill`; CLAUDE.md (power-ups list).

### Task 7: Ball gender and female hair styles

**Files:**
- Modify: `lib/features/ball_management/domain/custom_ball.dart` (`BallGender { none, male, female }`, field `gender`, copyWith), `lib/features/custom_groups/presentation/ball_editor_sheet.dart` (SegmentedButton None/Male/Female, key `ball-gender`), `lib/features/custom_groups/data/custom_group_repository.dart` (interface, Supabase impl, account wrapper: `gender` in addBall/updateBall; read column `gender` tolerant of its absence), `supabase/migrations/022_ball_gender.sql` (`alter table group_balls add column if not exists gender text not null default 'none' check (gender in ('none','male','female'))`), `replay_link.dart` (`c.` json key `x`, optional, validated), `match_simulation_controller.dart` (hair assignment ~l.345-406), `lib/features/arena_simulation/presentation/ball_hair_painter.dart` (female families), test fakes in `test/features/custom_groups/custom_groups_test.dart`
- Test: `custom_ball_test.dart`, `custom_groups_test.dart`, `replay_link_test.dart`, `ball_face_expression_test.dart` or a new `ball_hair_painter_test.dart`, `match_simulation_controller_test.dart` (determinism)

**Interfaces:**
- Produces: `enum BallGender { none, male, female }`, `CustomBall.gender`, `BallHairPainter` style pools `maleStyles` / `femaleStyles` (lists of style indexes; female families drawn in code: long straight, ponytail, two pigtails, bob, top bun, each with variants).

Rules:
- None: today's behavior exactly (random hair only when "Random hairstyles" is on, from the existing pool).
- Male / Female: the ball always gets hair from its gender's pool, whether or not "Random hairstyles" is on, shown in every look (faces, pictures, both), color from the existing hair palette.
- Determinism: never add RNG draws. When random hairstyles are on, map the already-shuffled `hairstyleOrder[i]` into the ball's pool (`pool[order % pool.length]`); when off, pick from the pool with a pure hash of the ball id (no RNG). The Threads pin and seed tests must pass unchanged.
- Existing 20 styles become the male pool (verify each family reads as short/male; move any that read as long/female into the female pool and say so in the commit).

- [ ] **Step 1: Failing tests**: editor saves gender (add and update); repository maps it both ways and saving still works when the column is missing (fake throws a column error once -> retried without `gender`); `c.` link round-trips `x` and rejects unknown values; a female ball gets a female-pool style in both looks with random hairstyles off and on; None balls are unchanged; same seed + same balls gives identical match results with and without genders set.
- [ ] **Step 2: Run** : FAIL.
- [ ] **Step 3: Implement**: model, editor, repository, migration, link, controller mapping, female hair families in `BallHairPainter` (vector paths, no blur, sized to the ball like the existing styles). Inspect them by rendering a contact sheet in a test (`render_hair_test` writing to the scratchpad or a golden) and look at it before committing.
- [ ] **Step 4: Run** focused then full `flutter test` : PASS.
- [ ] **Step 5: Commit** `feat: ball gender with female hair styles`; CLAUDE.md (groups + hair); note that migration 022 must be run in the Supabase SQL editor.
