# Ball Wars handoff

Updated: 2026-10-25 (UTC)

## Project and delivery context

- Owner: GitHub user `dbsuarez`.
- Repository: https://github.com/dbsuarez/ballwars
- Live web app: https://dbsuarez.github.io/ballwars/
- Stack: Flutter/Dart, CustomPainter simulation/rendering, Supabase.
- Primary working source: the owner's uploaded `lib.zip`, containing `lib/`, `test/`, Supabase migrations and `pubspec.yaml`. Sprite assets, platform projects and deployment workflows were not included.
- Edited project in this workspace: `/workspace/ballwars`.
- Direct Git access failed because the cloud network proxy was unreachable. The assistant did not push commits, create release tags or deploy anything directly.
- The owner uploads ZIPs into GitHub Codespaces from Android and runs Git commands there.
- Latest delivered cumulative archive: `ballwars-update-v016.zip`.
- All numbered archives are cumulative. Apply the newest archive rather than stacking older versions on top of it.
- ZIP versions are separate from Android release tags.

## User preferences and current scope

- Mobile usability is a priority: avoid repeated vertical swiping during testing, keep the arena visible and make controls easy to reach.
- Main menu now selects Threads, Mayhem or All-Out. The earlier deferral was superseded by the owner. The old Start a match button is replaced with the installed version, mode buttons and Android-only Quit game. Web has no Quit game. Match Setup retains Start to launch the actual fight.
- Use numbered, cumulative ZIPs: next update should be `ballwars-update-v017.zip`.
- Include copy/paste deployment commands with updates.
- Do not use en/em dashes in product UI text, per the supplied `CLAUDE.md`.
- Reuse the existing admin authorization (`AdminAuth.isAdmin()`). The user calls this superadmin; no separate superadmin role was introduced.

## Implemented changes

### Admin power-up test arena

Added `lib/features/settings/presentation/power_up_test_screen.dart`, linked from admin Settings under POWER-UP TESTS.

- Uses the real `MatchSimulationController`, power-up system and arena painter.
- Verifies admin access before showing controls.
- Supports Arsenal and All-Out.
- Defaults to Endless; eliminated balls respawn under existing Endless rules.
- Starts paused with Ball A assigned Pistol and Ball B unarmed.
- Select items with a searchable bottom-sheet picker; includes No item.
- A selection pauses/resets the test and is saved for subsequent Reset/Replay within that screen instance.
- Reset/Replay restores the selected items. Ordinary endless respawns retain the game's original equipment-clearing rules; automatic re-equipping on every respawn was not added.
- Separate re-equip buttons replenish an item during a fight.
- Freeze either or both balls in place while attacks, damage and timers continue. Position locks also suppress pulls, swaps, portals and knockback movement; unlock for those tests.
- Play/Pause, Reset, Step frame, 0.25x/0.5x/1x/2x playback.
- Separated, Contact and Natural starting layouts.
- Random spawns off initially; optional toggle in Fight setup.
- Main phone interface has no scrolling: arena, freeze controls, both item selectors and playback stay together. Long item lists and advanced setup scroll only inside their panels.
- BG and SFX toggles are visible in the app bar and use the existing shared device audio preferences.
- Live pickup, attack, hit, collision and explosion events play existing sounds.
- Enabling BG explicitly starts music during the tap gesture, including while paused. Other pause/reset transitions may still stop/pause music; verify expected behavior on the device.
- Info button beside re-equip opens the selected item's `powerUpDescription` using the active tuning and mode; opening it pauses the fight.

### Icon and finisher previews

- Two corner previews sit at the lower left/right of the arena, corresponding to Ball A/B.
- Preview icons have a fixed frame and center guides to inspect centering/bleed.
- Tapping a selected icon pauses the test and plays `HarpoonCinematic` with that ball as winner and the other as loser.
- Existing finisher profiles/sounds are used, including generic fallback profiles where no dedicated profile exists.
- Closing/completing preview returns to the unchanged, paused test.

### Mobile match setup

Modified `match_setup_screen.dart`.

- Settings are collapsed initially.
- Footer keeps mode selection, selected balls, a current-settings summary, Random and Start accessible.
- Edit match settings opens a bottom drawer.
- Drawer contains pickup selection, gameplay switches, rounds, speed, effects, size, wall sparks, audio and ball-look controls.
- Added All set beside the bottom sound/ball-look buttons; it closes the drawer. Top-right close remains.
- Settings sections, switches and compact setting tiles use cards.
- Changing away from Mayhem trims excess ball selections to the mode's allowed count.

### Independent pickup preferences

- Separate preference keys: `power-ups-threads`, `power-ups-arsenal`, `power-ups-allout`.
- The previous shared `power-ups` choice is inherited initially if a mode-specific choice is absent.
- Subsequent changes are saved per mode.
- Threads still has no power-up gameplay.
- Traps remain always enabled, following the existing rules; independent trap disabling was not added.

### Mobile battle layout

- `ScoreboardOverlay` gained a compact mode used for portrait battles.
- Compact cards show name/color, life or lines, KOs/series wins where applicable, progress and equipment icons.
- Six-player matches can use three columns on sufficiently wide phones, instead of six tall scoreboard rows.
- Reduced portrait padding gives more space to the arena.
- Full phone/landscape/text-scale validation remains necessary.

### Screen awake

Added `lib/core/widgets/screen_awake.dart` and dependency `wakelock_plus: ^1.2.8`.

- Used by running battles, running power-up tests and finisher previews.
- Releases on pause, match finish, background and disposal; requests again on resumed active screens.
- Browser wake-lock permissions/support can affect success.
- Native Android requires rebuilding/installing the APK to include the plugin; updating only the website cannot update an installed native app.

### Admin unarmed collision damage

- Added `unarmedCollision` tuning field to `PowerUpConfig`.
- Location: Admin Settings > Power-ups > Damage - Arsenal (life).
- Label: Unequipped ball collision damage.
- Default 5; allowed range 0-200. Zero disables body damage dealt by an unequipped ball.
- Applies to the attacking ball when both weapon slots are empty. Buffs do not count as equipped weapons.
- Equipped balls retain the original base body-collision damage; weapon/contact damage remains separate.
- Existing crowd scaling remains in effect.
- Stored in existing `app_settings.power_ups` JSON and included in replay tuning.
- No new Supabase migration.

### Arena weapons and visuals

- Knife/Sword held arena sprites doubled; placement and hand grip adjusted.
- Hook and Thread Harpoon get separate source-orientation corrections and hand placement. Hook was reversed by 180 degrees in v005 after user clarified their handles point opposite ways; Thread Harpoon was left unchanged then.
- Swap Cannon now emits portal flashes at both swapped locations and a SWAPPED label.
- Overcharge uses a larger aura and an explicit inner ring with the ball's radius.
- Lightning Strikes finisher draws overhead lightning bolts rather than throwing the item icon.
- Freeze projectile uses an isolated vector ice wave.
- Grenade flash uses an isolated radial effect. Explosion/ice animation frames use independent generated drawing paths, avoiding neighboring atlas pixels.
- Vampire/Repulsor use the existing clean authored pixel icons instead of the reported contaminated atlas crops.
- Original sprite sheets were unavailable; original artwork/crops were not visually inspected or edited.

### Tornado and damage over time

- Tornado was incorrectly marked burning by the shared DoT path.
- Burn visual is now restricted to fire damage types; Tornado retains its repeated damage without fire visuals.
- Poison, fire walls, flamethrower and Molotov areas already had damage-over-time behavior; these were not all newly introduced.

### Energy Wave

Initially deferred at the owner's request, then subsequently addressed.

- Fixed missing color stops in charge gradients in v002. User later reported Energy Wave was working.
- v007 changes the beam phase into a full 360-degree sweep over the existing two-second duration.
- Visible beam rotates with a faint swept-area trail and moving charge orb.
- Damage is applied once per opponent when the sweep reaches that opponent's bearing; damage amount remains unchanged.
- Existing charge, pause/freeze during cast, release/knockback behavior retained.
- Updated item description and affected simulation tests.
- The changed sweep still needs final device confirmation; do not describe it as production-verified.

### Settings and remembered login persistence

v003 changes cover web and Android:

- New `PersistentPreferencesStore` separates small preferences/settings backup from downloaded resource caches.
- Web stores `pref:*` and `settings` in localStorage, with migration from existing cached values. Resource downloads remain in Cache Storage.
- `DevicePrefs` serializes writes; idle/completed queue handling was improved in v008.
- Android `FileOfflineStore` serializes writes per key and waits on pending writes before reads, preventing same-temp-file races.
- Successful Supabase settings saves request the complete updated row and refresh the local offline settings backup.
- A cache-write failure no longer discards fresh server-loaded settings.
- Changed power-up settings cannot silently report a successful save if the `power_ups` column was not loaded.
- Startup admin session restoration completes before a new login begins.
- Temporary auth recovery failures preserve the saved session for a later launch; explicit invalid-token status codes clear it.
- User should sign in once with Remember me checked after deploying these changes.
- Already-erased data cannot be recovered by these changes.
- These are fixes for identified code paths, not proof that every reported persistence symptom has been resolved on-device.

### Mayhem win-screen tally

v010/v011:

- Winner screen receives the final contestant list and knockout counts.
- Shows all contestants, including zero KOs; actual winner gets a trophy marker.
- v011 adds remaining HP, displayed to one decimal.
- Ordering: knockout count descending, exact remaining life descending, original contestant order for complete ties. This matches `_finishMayhem`.
- Equal KOs and exact life share displayed rank.
- Data shape: `WinnerModal.mayhemTally` is optional `List<(CustomBall, int, double)>`.
- Normal non-Mayhem winner screens are unaffected.

## Numbered release history

| ZIP | Changes |
| --- | --- |
| v001 | First numbered cumulative bundle: test arena, mobile UI, persistence groundwork not yet v003, sprite/effect improvements, icon previews, unarmed collision tuning and earlier compile fix. |
| v002 | Added explicit color stops to isolated effect, grenade and charge radial gradients. |
| v003 | Web/Android settings and remembered-session persistence fixes and tests. |
| v004 | BG toggle explicitly starts music, including paused test preview. |
| v005 | Corrected Hook arena source orientation; Thread Harpoon unchanged. |
| v006 | All set button in match-settings drawer. |
| v007 | Energy Wave 360-degree sweep and sequential hit timing. |
| v008 | Preference write-queue cleanup and widget-test fake-clock persistence waits. |
| v009 | Corrected PostgREST mocks in settings-persistence tests. |
| v010 | Mayhem final knockout tally. |
| v011 | Remaining HP and life-based tally tie-break ranking. |
| v012 | Finisher Skip/preference; aligned tally columns; full-width grouped settings and content-sized drawer; fixed All set; tabbed A-Z item lists; audio/interactions; occupied-sector Energy Wave sweep; largest fully fitting arena. |

The current source tree and v015 archive include the v002-v009 fixes. Avoid reverting files by extracting an older ZIP afterward.

## Failures reported and corrections supplied

1. `_WeaponsDialogState` referenced `_update` defined only on the parent screen.
   - Caused by an overly broad callback replacement.
   - Three dialog callbacks restored to `setState`; included in numbered bundles.
2. Isolated sprite test threw `colors must have length 2 if colorStops is omitted`.
   - Added explicit stops to three-color radial gradients in v002.
3. Weapons-selection test timed out after ten minutes.
   - Direct storage setup/assertions moved into `tester.runAsync`; completed preference-write futures removed from the idle queue in v008.
   - Supplied fix; no subsequent explicit complete passing-run confirmation recorded here.
4. Settings-persistence tests hit a PostgREST null check.
   - HTTP mock responses lacked `request` metadata and GET fixtures used the wrong response shape.
   - Added originating requests and row-array GET fixtures in v009.
   - Supplied fix; final complete suite status still needs verification.

Do not remove or bypass deployment tests to force a release.

## Testing and verification status

- Flutter and Dart were not installed in the editing workspace.
- No complete `flutter analyze`, `flutter test`, web build or APK build was executed by the assistant.
- No real browser or Android visual/audio/wake-lock validation was executed by the assistant.
- Static relative-import/delimiter checks and ZIP integrity checks were used where stated. They do not establish compilation or runtime correctness.
- GitHub Actions logs supplied by the user showed broad passing coverage but also the specific failures above.
- Added/updated tests include power-up test controls/UI, collision tuning, Energy Wave feedback, compact scoreboards, match-settings drawer and mode preferences, screen-awake lifecycle, persistent stores, serialized preferences, Supabase save/backup behavior and Mayhem tally ordering.
- The latest v015 changes and updated tests have not been independently executed here.

Recommended validation in a full checkout:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --base-href /ballwars/
```

If testing a newly added native plugin locally produces a stale registrant error, perform a clean rebuild. Commit `pubspec.lock` if dependency resolution changes it in the full project.

## Outstanding checks and unresolved reports

- Unidentified power-up icons showing X: owner has not identified which items. Do not claim all X icons are fixed.
- Balls disappeared in an older-deployment screenshot with life still at 100. No confirmed reproduction on the newest release; investigate if it persists.
- Verify Hook grip/orientation, doubled blades, Overcharge size and the replacement effects with actual sprite assets on a phone.
- Verify the Energy Wave sweep and one-hit-per-target behavior in two-, four- and six-player fights, including interruptions and shields/ghosts.
- Verify BG audio begins from a user tap on Android Chrome and the native app; check lifecycle/pause/reset expectations.
- Verify screen stays awake during a running fight and releases appropriately.
- Verify power-up admin edits persist across reload, offline fallback, redeploy and Android upgrade; verify Remember me after closing/reopening both clients.
- Verify Mayhem tally, ties, zero KOs and full six-player phone layout after match completion.
- Moving game-mode selection to Home is deferred, not implemented.
- Tally changes were made to the in-app win screen; inclusion in exported replay video layouts was not requested or implemented.

## Supabase requirements

- No NEW migration was introduced by these changes.
- Existing migration 011 (`power_ups` settings JSON) is still required for persisted power-up tuning.
- If the new missing-column error appears, verify the existing schema/migration rather than adding an unrelated new migration.
- Authoritative shared settings remain in Supabase. Device preferences/admin remembered session/offline settings backup are local.

## Web deployment from Android Codespaces

Upload the newest ZIP into the repository root, then:

```bash
git switch master
git pull --ff-only origin master
unzip -o ballwars-update-v015.zip
git add lib test pubspec.yaml
git commit -m "Add editable rarity tiers and Mayhem loser ranking v015"
git push origin master
```

A push to master triggers the existing GitHub Pages workflow. Watch:
https://github.com/dbsuarez/ballwars/actions

If a run is unusually long, inspect the active step and logs; a previous test hung for ten minutes. If a run fails, copy the failed test and its exception/Expected/Actual details. A green deploy may still require checking whether the browser is serving an older app shell.

Do not clear browser site data as a first troubleshooting step: it can erase preferences and remembered sessions.

## APK release

- Owner stated the previous release was `1.14.3`.
- `v1.14.4` was suggested for the earlier release.
- `v1.14.5` was suggested for the Mayhem tally update.
- `v1.14.6` was suggested for v012; v1.14.7 for v013; v1.14.8 for v014; **v1.14.9** for v015. Publication of these tags was not independently verified.
- Actual creation/publication of these tags was not independently verified.
- Before publishing, verify which tags exist and that master contains the intended update.
- Based on supplied project documentation, pushing a `v*` tag triggers the signed APK release workflow.

For the latest discussed `v1.14.9` release, ONLY if unused and pointing at the intended tested commit:

```bash
git switch master
git pull --ff-only origin master
git tag v1.14.9
git push origin v1.14.9
```

Release downloads:
https://github.com/dbsuarez/ballwars/releases

Do not move an already-published release tag. Use the next unused release version. Preserve the existing Android signing key so upgrades retain app identity and data. Install updates without uninstalling to preserve local data.

## Key files for the next developer

- `lib/features/settings/presentation/power_up_test_screen.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/settings/data/app_settings_repository.dart`
- `lib/features/match_setup/presentation/match_setup_screen.dart`
- `lib/features/arena_simulation/application/match_simulation_controller.dart`
- `lib/features/arena_simulation/application/power_up_system.dart`
- `lib/features/arena_simulation/domain/power_up.dart`
- `lib/features/arena_simulation/domain/power_up_config.dart`
- `lib/features/arena_simulation/presentation/power_up_painter.dart`
- `lib/features/arena_simulation/presentation/power_up_sprites.dart`
- `lib/features/arena_simulation/presentation/ball_face_expression.dart`
- `lib/features/arena_simulation/presentation/harpoon_cinematic.dart`
- `lib/features/arena_simulation/presentation/arena_battle_screen.dart`
- `lib/features/arena_simulation/presentation/scoreboard_overlay.dart`
- `lib/features/arena_simulation/presentation/winner_modal.dart`
- `lib/core/widgets/screen_awake.dart`
- `lib/core/offline/device_prefs.dart`
- `lib/core/offline/persistent_preferences_store.dart`
- `lib/core/offline/offline_store_web.dart`
- `lib/core/offline/offline_store_io.dart`
- `pubspec.yaml`

Start from the full latest GitHub checkout and compare it with the cumulative ZIP before making further edits. Source provided here may not include independent changes the owner subsequently made in Codespaces. Read the repository's current instructions and release workflows before assuming their contents match the original uploaded snapshot.


## v012 follow-up (2026-10-25)

This section supersedes earlier behavior descriptions where noted.

- All finisher cinematics now have a Skip button. Completion is guarded to run
  once whether skipped or played normally. Match Settings > Appearance > Finishers
  is a saved device preference controlling automatic post-match cinematics.
  Explicit preview/replay actions remain available.
- Mayhem tally now reserves fixed widths for trophy, KO and remaining-HP columns,
  so values align across rows. The existing KO/life tie-break ordering remains.
- Match settings use full-width 52px-minimum tap rows, with icon, label and current
  value; tapping anywhere cycles choices. Gameplay, Appearance and Audio groups
  share this style. Old text-only tap targets and obsolete compact tile classes
  were removed.
- The drawer adapts up to 90% of available height, scrolling only its content;
  All set stays in a fixed bottom action area. One info popup explains settings.
- Both item pickers have Weapons, Power-ups and Traps tabs, with A-Z sorting within
  each category. Test picker search filters the currently selected category.
  Traps remain always on in the user-facing enable/disable picker.
- Energy Wave now uses the smallest occupied angular sector as viewed from its
  caster, excluding the largest empty gap, rather than completing a full circle.
  Hit timing follows the sector sweep; two-second duration and damage unchanged.
- Web SFX use media-player playback rather than low-latency mode. Music start
  requests guard against stale operations. Test audio toggles update immediately;
  SFX-on gives a confirmation click. Test music is independent of simulation
  pause/editing once started; leaving the screen stops it and restores menu music.
- Added interaction sound events for warp/swap, traps, freezing, repulsion, thread
  cutting and eliminations. Existing bounce/contact/weapon sounds are retained.
- Normal and test arenas remove extra internal world-space rim padding and use
  5 logical pixels of external side padding. The circle still respects available
  height; tall controls or landscape may make height the limiting dimension.
  Camera shake is reduced so the rim is less likely to leave the visible area.
- Added/updated tests for Skip, settings preference/tap width, tabs and energy
  sweep bounds. Static import/delimiter checks passed. Flutter, audio playback and
  visual verification were not executed in the assistant workspace.
- This update does not prove every reported audio failure is resolved; verify
  on Android Chrome and native Android with real assets and platform plugins.


## Current release checklist

- Latest source delivery: **ballwars-update-v015.zip** (cumulative).
- Latest suggested APK tag: **v1.14.9** (for v015). Creation/build/publication unverified.
- Next ZIP number: **v016**. Check actual GitHub tags before choosing the next APK version.
- v012 does not change Supabase schema. No new migration.
- The handoff is descriptive of local source and delivered archives; it is not
  confirmation that the newest source passed CI or is running on the live site.
- v012 broadens the settings UI substantially. Check existing widget tests and
  real phone layouts first if CI fails; do not remove tests to bypass deployment.
- Verify all setting rows respond to taps near both edges, not just the value
  text; check All set remains reachable while settings content scrolls.
- Check finishers On/Off persists across restart, Skip completes once, and manual
  previews remain available when automatic finishers are off.
- Check six-player Mayhem names, trophy, KO values and remaining HP align.
- Check both pickers show correct categories, retain selections, sort A-Z and
  have usable tab/search behavior with the Android keyboard open.
- Test BGM/SFX rapid toggles, resume/background, paused test editing, ball/rim
  collisions, portals/swap, freeze, traps, thread cuts and knockout feedback.
- Test the Energy Wave sector with opponents above/below/behind the caster and
  across the angular wrap boundary; verify one hit per opponent and interruption
  restores velocities. The sector uses caster-relative angular extremes, not
  simple screen-x sorting.
- Check the largest circle is fully visible in portrait and landscape, browser
  and APK, during camera shake, and when shrinking-arena mode is active. Height
  limits may prevent the rim reaching both side margins.

### Remaining known limits

- Original sprite assets were never supplied; final visual sprite alignment and
  bleeding checks require the complete repository/assets on a real device.
- The reported X icons remain unidentified.
- The old-deployment disappearing-ball report has no confirmed latest-version
  reproduction.
- Browser/Android audio fixes are implemented but not audibly verified here.
- Shared settings and Remember me fixes still require redeploy/restart/upgrade
  checks; previously erased data cannot be recovered.
- No complete passing CI run for the latest version was supplied in this thread.


## v013 compile correction

The v012 settings refactor accidentally removed `_CategoryFilter` along with
obsolete settings controls. CI reported the missing type in match setup and
custom-group test loading. v013 restores the original Mine/Default/Shared enum,
labels, pack tags and preference-name lookup. No behavior or schema change.
Flutter compilation/tests still need GitHub Actions verification.


## v014 user-selectable Cards/List and global item search

- Owner confirmed the v013 deployment succeeded. That confirms resolution of
  the `_CategoryFilter` loading errors in that run. It does not validate v014.
- The next instructed APK release after v013 was v1.14.7; tag publication is not
  independently verified. Check GitHub before choosing a later release version.
- Both settings layouts are preserved. List is the v012 grouped-row layout;
  Cards puts every setting into its own uniformly styled, fully tappable tile,
  under the same groups. The drawer's All set remains fixed at the bottom.
- A visible List/Cards segmented selector sits at the top right of the container.
- Cards is the default when there is no saved choice; explicitly choosing List
  or Cards is remembered per device in `pref:match-settings-layout`.
- The initially discussed admin/shared layout toggle was superseded by the owner.
  No admin flag, database column or migration was included for the layout.
- In the power-up TEST picker, nonblank search queries temporarily ignore the
  category tab and search all 44 item names, sorted A-Z. A status label indicates
  cross-category results. Clearing search restores the currently selected tab.
- Regression tests cover default Cards, remembered layouts, switching and full
  tile taps, plus cross-category search and restoring tab filtering.
- Static import/delimiter and archive checks passed; Flutter tests and visual
  verification were not executed in this workspace.
- Next cumulative source archive should be v015.


## v015 rarity system, superadmin assignment editor, Mayhem last-place loser

- Owner approved Normal/Rare/Epic tiers by overall power (not only unavoidable
  attacks), with default conditional pickup weights 50/30/20.
- Normal names are white, Rare blue, Epic purple. `PowerUpName` supplies dark-backed
  badges for readability on light themes. Menus show rarity words as well as colors.
- Defaults: Normal = Pistol, Knife, Apple, Speed, Magnet, Bow, Water Gun.
  Epic = Gatling, Thread Harpoon, Ghost, Overcharge, Golden Armor, Rocket Launcher,
  Omega Tendrils, Fire Wall Magic, Lightning Strikes, Earthquake, Tornado,
  Energy Wave, Flamethrower. Remaining non-trap items default to Rare.
- Superadmin editor: Settings > Power-ups > Edit item rarities. Uses the existing
  `AdminAuth.isAdmin()` role guard, not a newly invented separate role. Editable
  dropdown per pickup; save applies to everyone through existing power-ups JSON.
- Admin spawn weights: Settings > Power-ups > Edit power-up numbers, Rarity spawn
  weights. These are normalized weights; 50/30/20 yields the agreed percentages.
  Zero weights suppress a tier when another enabled positive-weight tier exists.
  The numbers editor rejects all three weights being zero. If enabled items only
  belong to zero-weight tiers, selection falls back uniformly over those items.
- Traps remain separate: existing start time, boundary placement, automatic
  inclusion, and fraction of eligible draws are preserved. 50/30/20 applies to
  the non-trap part of spawn draws, not to every spawn including traps.
- New `PowerUpSpawnSelector` uses only the seeded match RNG. It selects a tier,
  then an enabled item within it; empty tiers are skipped and shares normalized.
- Assignments live as `tier.<kind>` numeric overrides; weights as `rarity.normal`,
  `rarity.rare`, `rarity.epic` in existing app_settings.power_ups JSON.
- New replay tuning snapshots all tier assignments compactly in `_tiers` plus
  all three weights. Changed numeric tuning travels too. Defaults now produce a
  tuning payload for power-up replay links. Existing 2000-character tuning limit
  is retained. No new Supabase migration.
- Owner explicitly said not to worry about old replays. Legacy uniform-spawn
  compatibility was removed; current/new matches are the target.
- Restoring defaults in Power-up numbers preserves the separate item-rarity
  assignments while resetting numeric tuning and spawn weights.
- Mayhem `_finishMayhem` now sets lastEliminatedId from the bottom of the final
  KO/life/original-order ranking. Both red-X loser display and finisher target
  already consume that ID, so they now show last place rather than last KO or
  the fallback first non-winner. Winner ranking and damage rules are unchanged.
- Tests added for tier coverage, 50/30/20 sample proportions, trap share, empty
  tiers, deterministic seeded selection, admin reassignment/replay snapshots,
  editor authorization/save, and Mayhem KO/life loser selection.
- Tests were NOT executed here; Flutter/Dart remain unavailable. Relative imports,
  retained category enum, selected code paths, and ZIP integrity checked.
- Latest instructed APK tag before this update was v1.14.8 (for v014); publication
  unverified. Check actual GitHub tags before issuing another release tag.
- Next cumulative source ZIP should be v016.


## End-of-session status

- Latest cumulative source archive: **ballwars-update-v015.zip**.
- Latest instructed APK tag: **v1.14.9**, conditional on v015 passing GitHub Actions
  and the tag being unused. Creation/publication has not been confirmed.
- Owner confirmed a successful deployment after the v013 category-enum fix.
  No explicit CI-success confirmation was supplied for v014 or v015 afterward.
- Latest additions: user-selectable Cards/List layout (Cards default), global
  search in the test picker, editable Normal/Rare/Epic rarity tiers with 50/30/20
  default weights, and Mayhem last-place selection for the red X/cutscene loser.
- No new Supabase migration for these latest additions. The earlier proposed
  shared admin layout column/migration was abandoned in favor of device choices.
- New rarity assignments and weights use existing power_ups JSON. Old replay
  compatibility is explicitly out of scope per owner; new replays snapshot rarity.
- Next code ZIP: **v016**. If v1.14.9 has been published, the likely next release
  tag is v1.14.10, but inspect the repository tags before choosing it.
- Do not assume the local edits are production-verified: this workspace still
  lacks Flutter/Dart, full assets, platform projects and release workflows.
- Next session should begin by checking the latest GitHub Actions run and actual
  release state, then obtaining current repository source before further edits.

### Resume checklist

1. Confirm v015 CI and APK release status; collect full failure details if needed.
2. Test rarity editing as admin, persistence across restart, tier colors, weight
   changes, disabled-item behavior, and new replay round-trips.
3. Verify the Mayhem red-X/cutscene loser matches the bottom of the final tally,
   including tied KOs, unequal life, and complete ties.
4. Verify Cards/List choice, full-tile taps, fixed All set, all-category test
   search, largest fitting arena, Skip/finisher preference, BGM/SFX and wake lock.
5. Recheck unresolved X icons and the old disappearing-ball report only if they
   reproduce on the latest deployment. Final sprite alignment still needs assets.

### Latest web deployment commands

```bash
git switch master
git pull --ff-only origin master
unzip -o ballwars-update-v015.zip
git add lib test pubspec.yaml
git commit -m "Add editable rarity tiers and Mayhem loser ranking v015"
git push origin master
```

### Latest instructed APK release commands

Run only after the intended commit passes CI and if the tag is unused:

```bash
git switch master
git pull --ff-only origin master
git tag v1.14.9
git push origin v1.14.9
```


## v016 - latest session update

This section supersedes conflicting historical behavior above. Source is prepared,
not pushed or deployed. Expected APK tag is `v1.14.10` if unused. Next ZIP is v017.

### User-visible changes

- Main menu: Threads / Mayhem / All-Out open their corresponding match setup.
  Mayhem maps to Arsenal + Mayhem, with six contestants. No extra mode selector
  or Mayhem toggle appears in setups opened this way. Existing standalone setup
  callers retain their old selector to avoid breaking internal/tests behavior.
- The former Start a match location shows the installed version via
  package_info_plus; pubspec fallback is 1.14.10. Native builds use their actual
  build version. Quit game uses SystemNavigator.pop on Android only, never web.
- Mayhem Match time tile cycles 30s, 1, 2, 3, 5, 10 minutes. Default 2 minutes,
  saved on-device as mayhem-seconds. Config, long replay links, Home replay entry,
  prediction and video export all carry mayhemSeconds.
- Clock clamps at the chosen deadline; battle and test simulations ignore all
  non-resumed lifecycle states. First frame after resume only resets delta.
- An original synthesized whistle plays once on Mayhem finish, respecting SFX.
  New bundled asset: assets/sounds/whistle.wav (mono PCM, 22050 Hz, 0.85 sec).
- In-match bottom-left SFX and bottom-right BGM buttons match test arena reach.
- Visible icon artwork fills up to 60px of a 64px icon, retaining aspect ratio
  and a 2px border. Alpha bounds are calculated once during sprite loading.
  Pixel fallback icons are fitted to occupied pixels too. No per-frame scan.

### Sound investigation and changes

- Sound pools previously persisted across matches and focus interruptions,
  retaining native handles. There was no recreation on playback errors.
  Asynchronous music pause/stop/play commands could also race on one player.
- Effects now use ReleaseMode.stop and mediaPlayer on both platforms, guard
  per-player command overlap, retire failed handles, time out plugin commands,
  and recreate pools on new matches, test reset, SFX toggles and lifecycle changes.
- Effect throttling uses Stopwatch rather than wall-clock DateTime, avoiding
  suppression if device clock moves backwards. Effects are foreground-only.
- Music/menu operations each have a serialized queue and generation checks.
  Lifecycle resume restarts/resumes through the guarded path. Failed music
  handles are cleared so a later toggle/resume creates a new player.
- These address concrete code weaknesses; the reported native/browser audio
  failure has NOT been reproduced or audibly verified in this workspace. Do not
  claim it can never recur. Phone and web restart/focus tests remain essential.

### Branding persistence

- Branding belongs in Supabase app_settings.arena_title / arena_subtitle, supplied
  by existing migration 014_arena_text.sql. No new schema migration introduced.
- Found a silent-discard path: repository skipped these columns if not loaded
  yet still reported success. Changed branding now throws an actionable error
  when either column is unavailable. Saved values must match the server-returned
  row before cache is updated. An ordinary reload does not run a DB reset.
- Cannot inspect the owner's DB here, so absent migration is a possible cause,
  not a confirmed diagnosis. Apply existing 014 only if absent; it uses ADD IF
  NOT EXISTS and does not overwrite values in existing columns. Archive includes
  it for reference. Branding already lost to defaults cannot be recovered here.

### Replay sharing limitation caught during this update

The current short-link table/repository omits Mayhem/Endless/dual-wield/shrink and
now duration. Creating a short link with these flags now throws before any auth
or database call; the battle's existing catch keeps the complete long replay URL.
This avoids a successful-looking short link that changes the match. Extending
short-link storage is separate future work, not a new migration in v016.
Video export also now receives dualWield/endlessBattle/Mayhem settings; the
exported winner layout still does not show the Mayhem KO tally.

### Validation status

- Added regression coverage for bounce after reset, failed sound handle recovery,
  background effect suppression, music stop/start ordering, background clock
  pausing, deadline clamping, duration replay round-trip/rejection, icon fit,
  branding save/offline reopen, and unsupported short-link fallback.
- Updated home navigation test for mode entry; earlier tests retained.
- Static local-import checks, comparison of delimiter lexer flags to baseline,
  WAV format and cumulative archive integrity checked here.
- Flutter and Dart are not installed and most original assets/platform/workflow
  files were not uploaded. flutter analyze / flutter test / web or APK builds
  were NOT run. CI and on-device tests are required before release.
- Required runtime checks: finish and restart >=10 matches; ensure rim bounces
  and ball hits remain audible; toggle BGM/SFX while paused/running; switch apps,
  lock/unlock and return; finish 30s and longer Mayhem with no clock overshoot;
  inspect icon borders; save branding then reload web and restart Android.

### v016 source deployment

Run inside the existing repository (upload ZIP first):

```bash
git switch master
git pull --ff-only origin master
unzip -o ballwars-update-v016.zip
flutter pub get
flutter analyze
flutter test
git add lib test pubspec.yaml assets/sounds/whistle.wav supabase/migrations/014_arena_text.sql BALLWARS-HANDOFF.md UPDATE-VERSION.txt UPDATE-INSTRUCTIONS.txt
git commit -m "Improve match audio recovery and Mayhem controls v016"
git push origin master
```

After CI succeeds, if unused:

```bash
git tag v1.14.10
git push origin v1.14.10
```


## v016 - latest session update

This section supersedes conflicting historical behavior above. Source is prepared,
not pushed or deployed. Expected APK tag is `v1.14.10` if unused. Next ZIP is v017.

### User-visible changes

- Main menu: Threads / Mayhem / All-Out open their corresponding match setup.
  Mayhem maps to Arsenal + Mayhem, with six contestants. No extra mode selector
  or Mayhem toggle appears in setups opened this way. Existing standalone setup
  callers retain their old selector to avoid breaking internal/tests behavior.
- The former Start a match location shows the installed version via
  package_info_plus; pubspec fallback is 1.14.10. Native builds use their actual
  build version. Quit game uses SystemNavigator.pop on Android only, never web.
- Mayhem Match time tile cycles 30s, 1, 2, 3, 5, 10 minutes. Default 2 minutes,
  saved on-device as mayhem-seconds. Config, long replay links, Home replay entry,
  prediction and video export all carry mayhemSeconds.
- Clock clamps at the chosen deadline; battle and test simulations ignore all
  non-resumed lifecycle states. First frame after resume only resets delta.
- An original synthesized whistle plays once on Mayhem finish, respecting SFX.
  New bundled asset: assets/sounds/whistle.wav (mono PCM, 22050 Hz, 0.85 sec).
- In-match bottom-left SFX and bottom-right BGM buttons match test arena reach.
- Visible icon artwork fills up to 60px of a 64px icon, retaining aspect ratio
  and a 2px border. Alpha bounds are calculated once during sprite loading.
  Pixel fallback icons are fitted to occupied pixels too. No per-frame scan.

### Sound investigation and changes

- Sound pools previously persisted across matches and focus interruptions,
  retaining native handles. There was no recreation on playback errors.
  Asynchronous music pause/stop/play commands could also race on one player.
- Effects now use ReleaseMode.stop and mediaPlayer on both platforms, guard
  per-player command overlap, retire failed handles, time out plugin commands,
  and recreate pools on new matches, test reset, SFX toggles and lifecycle changes.
- Effect throttling uses Stopwatch rather than wall-clock DateTime, avoiding
  suppression if device clock moves backwards. Effects are foreground-only.
- Music/menu operations each have a serialized queue and generation checks.
  Lifecycle resume restarts/resumes through the guarded path. Failed music
  handles are cleared so a later toggle/resume creates a new player.
- These address concrete code weaknesses; the reported native/browser audio
  failure has NOT been reproduced or audibly verified in this workspace. Do not
  claim it can never recur. Phone and web restart/focus tests remain essential.

### Branding persistence

- Branding belongs in Supabase app_settings.arena_title / arena_subtitle, supplied
  by existing migration 014_arena_text.sql. No new schema migration introduced.
- Found a silent-discard path: repository skipped these columns if not loaded
  yet still reported success. Changed branding now throws an actionable error
  when either column is unavailable. Saved values must match the server-returned
  row before cache is updated. An ordinary reload does not run a DB reset.
- Cannot inspect the owner's DB here, so absent migration is a possible cause,
  not a confirmed diagnosis. Apply existing 014 only if absent; it uses ADD IF
  NOT EXISTS and does not overwrite values in existing columns. Archive includes
  it for reference. Branding already lost to defaults cannot be recovered here.

### Replay sharing limitation caught during this update

The current short-link table/repository omits Mayhem/Endless/dual-wield/shrink and
now duration. Creating a short link with these flags now throws before any auth
or database call; the battle's existing catch keeps the complete long replay URL.
This avoids a successful-looking short link that changes the match. Extending
short-link storage is separate future work, not a new migration in v016.
Video export also now receives dualWield/endlessBattle/Mayhem settings; the
exported winner layout still does not show the Mayhem KO tally.

### Validation status

- Added regression coverage for bounce after reset, failed sound handle recovery,
  background effect suppression, music stop/start ordering, background clock
  pausing, deadline clamping, duration replay round-trip/rejection, icon fit,
  branding save/offline reopen, and unsupported short-link fallback.
- Updated home navigation test for mode entry; earlier tests retained.
- Static local-import checks, comparison of delimiter lexer flags to baseline,
  WAV format and cumulative archive integrity checked here.
- Flutter and Dart are not installed and most original assets/platform/workflow
  files were not uploaded. flutter analyze / flutter test / web or APK builds
  were NOT run. CI and on-device tests are required before release.
- Required runtime checks: finish and restart >=10 matches; ensure rim bounces
  and ball hits remain audible; toggle BGM/SFX while paused/running; switch apps,
  lock/unlock and return; finish 30s and longer Mayhem with no clock overshoot;
  inspect icon borders; save branding then reload web and restart Android.

### v016 source deployment

Run inside the existing repository (upload ZIP first):

```bash
git switch master
git pull --ff-only origin master
unzip -o ballwars-update-v016.zip
flutter pub get
flutter analyze
flutter test
git add lib test pubspec.yaml assets/sounds/whistle.wav supabase/migrations/014_arena_text.sql BALLWARS-HANDOFF.md UPDATE-VERSION.txt UPDATE-INSTRUCTIONS.txt
git commit -m "Improve match audio recovery and Mayhem controls v016"
git push origin master
```

After CI succeeds, if unused:

```bash
git tag v1.14.10
git push origin v1.14.10
```
