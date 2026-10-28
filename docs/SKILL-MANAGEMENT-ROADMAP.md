# Ball Wars Development Roadmap

## Meaning of complete

Skill Management is fully complete when an administrator can create a genuinely new skill without changing Dart code, use it live, test it safely, synchronize it across devices, and reproduce it in replay links and videos.

This is now the authoritative Ball Wars development roadmap, not only the
Skill Management roadmap. A partial implementation does not count as complete:
an item stays unchecked until its requested live behavior and UX are verified.
Replay and video remain last, by agreement.

## Phase 1 - Built-in tuning and custom variants

**Status: Complete and deployed**

- [x] Edit built-in skill values.
- [x] Add Weapons, Power-ups, and Traps tabs with cross-category search.
- [x] Duplicate and activate one custom variant per base skill.
- [x] Apply damage, duration, count, speed, spread, bounce, and knockback live.
- [x] Select sprite/vector presentation and curated sounds.
- [x] Persist and synchronize the versioned library through Supabase.

## Phase 2 - True Custom Skill Builder

**Status: Complete and deployed**

### Shipped

- [x] Create a skill from scratch using a carrier pickup/icon.
- [x] Compose pickup, aimed-fire, or collision triggers.
- [x] Target self, the nearest opponent, or every opponent.
- [x] Deliver an instant, projectile, or area effect.
- [x] Apply damage, healing, freeze, speed, or knockback.
- [x] Preview item/impact rendering, tier-colored skill names, callouts, and sound in one replayable skill preview.
- [x] Customize yells with Shout, Speech, Thought, or Radio bubbles and Normal, Rare, Epic, or Special styling.
- [x] Preview damaging finishers.
- [x] Restore editor defaults and show a settings guide.
- [x] Use stable IDs and deterministic seeded execution.
- [x] Enable, disable, duplicate, edit, and delete custom skills.

### Remaining

- [x] Add timer, damage-taken, and elimination triggers.
- [x] Add chosen-direction and arena-location targeting.
- [x] Add beam, aura, orbit, and boundary-hazard delivery.
- [x] Add DoT, shield, pull, teleport, stun, and equipment effects.
- [x] Add repeat count and repeat interval.
- [x] Add start delay, DoT tick interval, and cooldown.
- [x] Add configurable colors and screen shake.
- [x] Validate trigger, target, delivery, and carrier compatibility.
- [x] Add explicit one-handed/two-handed equipment choice.
- [x] Chain primary and secondary effects in a defined order.

## Phase 3 - Testing, previews, and safety

**Status: Complete and deployed**

- [x] Add custom skills to Power-up Test, including unsaved editor drafts.
- [x] Add full projectile and effect playback through the live test arena.
- [x] Add sound, yell, callout, and finisher previews.
- [x] Show clear validation errors for impossible combinations.
- [x] Add deterministic simulation tests for the initial composed runtime.
- [x] Add Mayhem performance limits for effect-heavy combinations.
- [x] Verify shared-backend browser/phone synchronization with multi-client repository tests.
- [x] Provide strict versioned JSON import/export with draft-before-publish behavior.
- [x] Match default live callout styling to each item's actual Normal, Rare, Epic, or Special tier.

## Phase 4 - Gameplay correctness and battle feedback

**Status: Complete**

- [x] Eliminate Arsenal balls as soon as life is below 1; never show a living 0 HP ball.
- [x] Make Energy Wave stable at fast speed, keep the caster fixed during the cutscene, react every struck ball, and apply configurable knockback.
- [x] Make DoT-only skills deal no initial damage when configured that way.
- [x] Make Gremlin reverse the affected opponent's next complete volley everywhere; Power-up Test uses the same shared behavior.
- [x] Trigger Magnetic Force Field once per attacking opponent and make returned attacks damage their attacker.
- [x] Make Mirror-reflected attacks damage their original attacker.
- [x] Slam Omega Tendrils victims away from the caster.
- [x] Make equipped knife and sword sit in the hands; apply slash effect and SFX on collision.
- [x] Attach callouts to their ball so they follow movement.
- [x] Verify no duplicate unclaimed pickup of the same kind can exist.
- [x] Make frozen targets take configurable 1.5x damage and 5 collision damage.
- [x] Mask battle initialization with a deterministic Round Start countdown.
- [x] Show the active match mode in the match menu and use mode-specific labels such as Threads Match.

## Phase 5 - Complete Skill Management parameter model

**Status: Complete**

- [x] Expose initial damage independently from DoT damage, including zero-initial-damage skills.
- [x] Expose per-skill damage, DoT, duration, tick interval, range, speed, knockback, stun, freeze, pull, healing, and shield parameters.
- [x] Expose projectile count, size, sprite/vector rendering, speed, spin, spread/scatter, homing, bounce count, and return behavior.
- [x] Expose equipped weapon display scale globally or per item.
- [x] Expose per-weapon grip inset so hilted artwork originates at the ball's hand.
- [x] Expose Maximum Power's empowerment amount and duration.
- [x] Expose Repulsor values in Skill Management while retaining legacy Power-up Numbers.
- [x] Allow Speed to deal configurable damage.
- [x] Expose Time Bubble range.
- [x] Expose frozen-target damage multiplier and collision damage.
- [x] Expose equipped-artwork opponent tracking as a per-skill weapon option instead of a Shield-only behavior.
- [x] Show effect- and delivery-dependent editor parameters only when relevant, with an explicit Healing effect toggle for intentional healing weapons.
- [x] Ensure every parameter is consumed by the shared live runtime, Power-up Test, and all balls.
- [x] Retain duplicate-and-edit support for creating related skills.
- [x] Keep Power-up Numbers as clearly labeled legacy settings until Skill Management fully replaces it.

## Phase 6 - Admin, match setup, and Power-up Test UX

**Status: Complete**

- [x] Lock mobile gameplay to portrait orientation.
- [x] Remember rounds, speed, size, look, effects, finishers, Mayhem, and pickup selections as a separate complete profile for each game mode (tracked in Phase 11).
- [x] Let users enable or disable automatic per-minute battle acceleration and preserve the choice in replays and videos.
- [x] Organize Admin Settings into clear category tabs without long scrolling.
- [x] Rework legacy Power-up Numbers into Common, Arsenal, and All-Out tabs with fixed side-by-side Restore and Save actions.
- [x] Include arrow count and every missing legacy power-up value.
- [x] Use concise `DoT` labels everywhere.
- [x] Use admin branding text in Power-up Test.
- [x] Changing a Power-up Test selection must not reset ball positions; only Reset Fight may do that.
- [x] Separate Power-up Test selectors for Ball A, Ball B, and arena traps without changing arena size.
- [x] Put Play, Reset Fight, Skip Frame, and Speed in one compact row.
- [x] Support two weapons plus one power-up per ball in Power-up Test.
- [x] Remember and visibly restore every Power-up Test selection and its last category tab.
- [x] Put arena BGM and SFX controls side by side on the right and fix missing icons.
- [x] Add a separate UX-sound channel alongside BGM and SFX.
- [x] Make BGM, SFX, and UX sound tap-to-toggle and long-press-for-volume; default to 100/90/90.
- [x] Surface all three audio channels in Match Setup, the live arena, and Power-up Test through one compact volume popup.
- [x] Give Power-up Test a full-width mobile arena, three trap slots, compact icon-only playback, and responsive Weapon 1 / Weapon 2 / Power-up finisher previews.
- [x] Allow My Groups balls without uploaded pictures by using generated initials.
- [x] In Mayhem, hide groups with fewer than six balls.
- [x] Add centered horizontal-and-vertical empty-state animation to every empty list.
- [x] Add a configurable hands-on-picture-faces option.
- [x] Add Picture, Face, and Both face modes; Both uses a lower-opacity picture under the face.
- [x] Add a toggle for white pickup backgrounds while preserving the pulse.

## Phase 7 - Sprite, effects, and audio asset system

**Status: Complete**

- [x] Document and enforce fixed cell size, safe area, centering, transparency, animation frames, naming, and atlas rules.
- [x] Support manually added sprites through the same validated asset pipeline.
- [x] Produce an external-generation prompt for a proper lightning sprite that follows the sprite standard.
- [x] Let admins choose sprite or vector/fallback rendering for projectiles and explosion/freeze effects.
- [x] Add capped persistent shell casings that fall and collect at the arena bottom.
- [x] Replace Swap Cannon's effect with a dramatic Goku-style teleport treatment.
- [x] Match Thread Harpoon and Hook projectile size to their held weapon.
- [x] Replace Tornado rotation with a purpose-built animated sprite.
- [x] Show fire on both hands while Firewall is equipped instead of displaying its pickup icon.
- [x] Keep effect bounds transparent so rectangular containers never appear.

## Phase 8 - New content, Mayhem, ranking, and experiments

**Status: Complete**

- [x] Add epic Fried Chicken: restore to full health, but do nothing at 100 HP or above.
- [x] Add gold Special Sniper Rifle: unavoidable dramatic one-shot.
- [x] Add gold Special Cloud's Buster Sword: freeze time, target the farthest opponent, slash eight times, and yell `OMNISLASH!`.
- [x] Add epic Raging Demon: dash to the nearest opponent, darken the arena, flash 24 configurable one-damage hits, and make it dramatic.
- [x] Add Special tier and configurable spawn weights with defaults 50/45/40/35.
- [x] Add Mayhem KO tally.
- [x] Add a separate Mayhem tally for how many times each ball was eliminated.
- [x] Rank Mayhem by wins/KOs, then fewer eliminations, then remaining health.
- [x] Define ranking by wins, losses, then remaining HP.
- [x] Decide whether arena branding should rotate every minute; default remains static until approved.
- [x] Research non-circular contestants and document physics/fairness implications before implementation.
- [x] Let players choose and remember an arena in match setup while retaining the admin arena configuration surface.
- [x] Show the selected arena's automatic themed trap in the player-facing Traps section.
- [x] Make arena traps admin-configurable without turning them into player pickups.
- [x] Expose the shared arena-trap configuration in Skill Management > Built-in > Traps as well as legacy Power-up Numbers.
- [x] Put Item rarity directly in each weapon or power-up editor; retain the Gameplay rarity screen as a clearly labeled legacy editor.
- [x] Add a Chaotic arena mashup that deploys all four arena-only traps.

## Phase 9 - Replay links and video export

**Status: Complete pending final real-device verification**

- [x] Store immutable custom-skill definitions or version references in replay data.
- [x] Preserve old replay behavior after a skill is edited.
- [x] Render custom presentation in replay playback.
- [x] Render the same presentation in exported videos.
- [x] Add backward-compatible decoding and payload-size limits.
- [x] Verify deterministic live, replay, and video results.
- [x] Show elapsed export time while saving video.
- [x] Ask whether BGM and/or SFX should be included in the export and mux the selected channels into web and Android video output.
- [x] Keep the screen awake for the entire video export.
- [x] Reproduce the complete non-interactive battle UX and finishing cutscenes in replay/video.
- [x] Let users save replays.
- [x] Hide Replay Finisher whenever finishers are disabled.
- [x] Keep interactive player controls out of exported replay video.

## Phase 10 - Independent skill model and editor correctness (2026-10-27)

Architecture reference: [Recommended Skill Model](RECOMMENDED-SKILL-MODEL.md).

**Status: Complete**

- [x] Fix built-in skill persistence so edited Boomerang damage, knockback, and every exposed parameter survive Save, reload, and cross-device synchronization.
- [x] Replace carrier-derived classification with an explicit skill category: Weapon, Power-up, Trap, or Arena trap.
- [x] Add explicit capabilities/purpose so a skill may damage, heal, defend, or combine effects such as Vampire without exposing irrelevant fields.
- [x] Make custom skills independent additions with their own identity and spawn eligibility instead of replacing the built-in item that supplied their carrier/icon.
- [x] Remove remaining hard-coded behavior gates from `PowerUpKind`; composed/custom skills honor explosion, knockback, return-to-origin, delivery, targeting, and secondary effects at runtime.
- [x] Make duplicated BOOM-MERANG support explosion plus knockback and obey disabled return-to-origin.
- [x] Keep legacy built-ins backward compatible while migrating them into the same editable model.
- [x] Fix Power-up Test category placement so Fried Chicken and every skill use their explicit category rather than being mounted as weapons.
- [x] Restore live speech bubbles for built-in, edited, duplicated, and newly created skills.
- [x] Add configurable speech-bubble duration and preserve it in live battles, previews, replays, and video snapshots.
- [x] Give item-sprite and impact-sprite previews identical dimensions and alignment.
- [x] Put arena-only traps in Skill Management's Traps category, visibly marked `Arena`.
- [x] Add a generic code-drawn fallback icon for skills and arena traps without artwork.
- [x] Never generate paid image assets automatically; provide generation prompts for externally produced assets and integrate supplied files.
- [x] Move the admin Groups card to the Gameplay tab while preserving the legacy settings labels.

## Phase 11 - Arena hazards, modes, and battle feedback (2026-10-27)

**Status: Complete**

- [x] When Desert Quicksand releases/expires, expel affected balls away from its center and restore motion so nobody remains stranded.
- [x] Confirm Mayhem match time remains visible during the battle and on the result screen; add regression coverage for both.
- [x] Animate Neon Laser Gate glow, add matching crossing/hit SFX, and draw a visible dark emitter/source at each endpoint.
- [x] Audit Wilderness Vine Snare artwork and retain its animated code-drawn vine fallback because no suitable standalone vine sprite is available.
- [x] Persist separate complete match-setting profiles for Threads, Arsenal, Mayhem, and All-Out.
- [x] Add a clear Saved Replays browser/player so users can list, open, replay/export, and delete saved replays instead of only relying on the last replay shortcut.
- [x] Make arena outer-glow width user-adjustable and replay-safe.
- [x] Add green and custom-picker blood colors and preserve them in settings/replays.
- [x] Aim Tornado before casting; show wind effects on the ball's hands instead of mounting the tornado artwork.
- [x] Add reusable configurable hand-effect visuals (effect, scale, color, duration) and migrate Firewall and Tornado to them.
- [x] Add countdown SFX and delay match BGM until the countdown completes.

## Phase 12 - Match setup information architecture and ball hair (2026-10-27)

**Status: Complete**

- [x] Use Gameplay, Appearance, and Audio tabs in Match Settings for both list and card layouts.
- [x] Replace the generic `New Match` heading/action label with the selected mode: Threads, Arsenal, Mayhem, or All-Out.
- [x] Add a pre-match user toggle for randomized hairstyles.
- [x] Design 20 lightweight code-drawn hairstyles with independently assigned colors.
- [x] Assign unique hairstyles within each match and prevent hair color from matching the ball body color.
- [x] Preserve hairstyle assignments in replay data and exported video.

## Final completion checks

### Continuation from Claude (2026-10-28)

- [x] Production migration `022_ball_gender.sql`: user confirmed applied in Supabase.
- [x] Add approved player rarity presets, per-mode Custom settings, live tier odds and immutable match tuning. See [rarity presets](RARITY-PRESETS.md).
- [x] Verify rarity presets with 390px Cards/List UI tests, per-mode settings, invalid input, seeded odds and historical tuning defaults. Full suite: 724 passed; static analysis and release web build passed (2026-10-28).
- [ ] Hands-on browser and Android acceptance of rarity preset controls.
- [ ] Implement the in-app sprite importer (Plan 2); choose an unused migration number after `022_ball_gender.sql`.

### Follow-up polish (2026-10-27)

- [x] Split Edit Skill into Identity (including behavior), Damage & Timing, Appearance, and Callouts & Sounds tabs, retaining draft values and persistent preview actions.
- [x] Save directly from Edit Skill to the settings repository, retaining the editor and showing failures for retry; keep Save Library for bulk library changes.
- [x] Add per-skill Artwork tint in Appearance, including a gold swatch and original-color reset. Persist tint in skill/replay data and apply it to icons, held/dropped artwork, projectiles, skill effects and finishers without modifying shared source images.
- [x] Use numeric up/down controls for whole-number skill fields, retaining direct typing and enforcing minimum/maximum bounds; preserve decimal inputs for fractional settings.
- [x] Add general Effect visuals selection, admin defaults starting at Sprite, and per-mode player preferences preserved in replay links and exports. Explicit skill choices override the shared default.
- [ ] Add independent equipped artwork and fired-skill selection (Knife firing three Boom-merangs). See [next feature handoff](NEXT-SKILL-COMPOSITION.md).
- [x] Default newly saved replay names to local date/time and filename-safe contestant names with a `.bw` suffix; preserve custom names on re-save.

- [x] Implement the [Skill Management audit](SKILL-MANAGEMENT-AUDIT.md): grouped fixed-label controls, visible validation, aligned sprite/projectile previews, and runtime sizing/parameter corrections.
- [x] Add opt-in replay server upload and cached short-link sharing while retaining local offline playback.
- [x] Apply production migration `020_replay_documents.sql` to enable full replay documents on the server. User confirmed applied in production on 2026-10-27; end-to-end replay sharing verification remains part of the checks below.

- [x] Pass each mode's finisher choice into the live battle rather than reading a stale global setting.
- [x] Add Laser Gate and Quicksand finisher profiles and gallery previews using their arena hazard renderer. Gravity Well and Vine Snare do not directly damage balls and remain excluded.
- [x] Reuse existing fire, ice, tornado, slash, explosion and projectile artwork in finishers; add missing elemental presentations and preserve custom-skill carrier artwork.
- [x] Use the Mayhem table layout for match and series results in every mode, with health or remaining threads and elimination counts.
- [x] Add Rename to saved replay options and persist the name without changing playback data.
- [x] Replace hex-only Effect color entry with a visual picker for all skills, with swatches, hue, saturation and brightness controls.

- [x] Final static analysis and automated tests pass (452-test full suite; 2026-10-27), including actual equipped-size pixel rendering and a 390px editor layout.
- [ ] Browser verification passes.
- [ ] Android phone verification passes.
- [ ] Cross-device synchronization passes.
- [ ] Production deployment is verified.

## Current position

2026-10-27 verification fixes:
- [x] Upgrade saved legacy custom skills to executable shared-model definitions; verify impact explosion, sound and knockback on a duplicated Boomerang.
- [x] Separate Mayhem settings and pickups from Arsenal, including default restoration when switching profiles.
- [x] List Gravity Well, Quicksand, Vine Snare and Laser Gate individually under Traps with an Arena marker and relevant controls.

```text
[x] Phase 1 -> [x] Phase 2 -> [x] Phase 3 -> [x] Phase 4 -> [x] Phase 5 -> [x] Phase 6 -> [x] Phase 7 -> [x] Phase 8 -> [x] Phase 9 -> [x] Phase 10 -> [x] Phase 11 -> [x] Phase 12 -> Fully complete
```
