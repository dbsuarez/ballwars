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
- [x] Expose Maximum Power's empowerment amount and duration.
- [x] Expose Repulsor values in Skill Management while retaining legacy Power-up Numbers.
- [x] Allow Speed to deal configurable damage.
- [x] Expose Time Bubble range.
- [x] Expose frozen-target damage multiplier and collision damage.
- [x] Ensure every parameter is consumed by the shared live runtime, Power-up Test, and all balls.
- [x] Retain duplicate-and-edit support for creating related skills.
- [x] Keep Power-up Numbers as clearly labeled legacy settings until Skill Management fully replaces it.

## Phase 6 - Admin, match setup, and Power-up Test UX

**Status: Complete**

- [x] Lock mobile gameplay to portrait orientation.
- [x] Remember match settings, including rounds, speed, mode, size, look, effects, finishers, Mayhem, and per-mode pickups.
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
- [x] Add Mayhem elimination tally.
- [x] Define ranking by wins, losses, then remaining HP.
- [x] Decide whether arena branding should rotate every minute; default remains static until approved.
- [x] Research non-circular contestants and document physics/fairness implications before implementation.
- [x] Let players choose and remember an arena in match setup while retaining the admin arena configuration surface.
- [x] Show the selected arena's automatic themed trap in the player-facing Traps section.
- [x] Make arena traps admin-configurable without turning them into player pickups.
- [x] Expose the shared arena-trap configuration in Skill Management > Built-in > Traps as well as legacy Power-up Numbers.
- [x] Fold Item Rarities into Skill Management while retaining the existing Settings shortcut.
- [x] Add a Chaotic arena mashup that deploys all four arena-only traps.

## Phase 9 - Replay links and video export

**Status: Last, by agreement**

- [ ] Store immutable custom-skill definitions or version references in replay data.
- [ ] Preserve old replay behavior after a skill is edited.
- [ ] Render custom presentation in replay playback.
- [ ] Render the same presentation in exported videos.
- [ ] Add backward-compatible decoding and payload-size limits.
- [ ] Verify deterministic live, replay, and video results.
- [ ] Show elapsed export time while saving video.
- [ ] Ask whether BGM and/or SFX should be included in the export.
- [ ] Keep the screen awake for the entire video export.
- [ ] Reproduce the complete non-interactive battle UX and finishing cutscenes in replay/video.
- [ ] Let users save replays.
- [ ] Hide Replay Finisher whenever finishers are disabled.

## Final completion checks

- [ ] Final static analysis and automated tests pass.
- [ ] Browser verification passes.
- [ ] Android phone verification passes.
- [ ] Cross-device synchronization passes.
- [ ] Production deployment is verified.

## Current position

```text
[x] Phase 1 -> [x] Phase 2 -> [x] Phase 3 -> [x] Phase 4 -> [x] Phase 5 -> [x] Phase 6 -> [x] Phase 7 -> [x] Phase 8 -> [ ] Phase 9 -> Fully complete
```
