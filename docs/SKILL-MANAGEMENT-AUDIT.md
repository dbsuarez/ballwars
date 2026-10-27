# Skill Management implementation audit

Date: 2026-10-27

This pass inspected the editor, model serialization, settings application, equipped skill identity, simulation handlers and arena drawing paths. Findings below were implemented, rather than recorded only as recommendations.

## Editor

- [x] Group Identity, Behavior, Damage & timing, Appearance, and Callouts & sound.
- [x] Use fixed Label | Control rows, with right-aligned numeric values and separate spaced cards.
- [x] Keep Preview, Live test and Finisher actions available in a persistent action bar.
- [x] Give both visual previews equal width, height and header space; center their artwork independently of controls below.
- [x] Preview projectile artwork rather than repeating the held weapon icon.
- [x] Show artwork in visual-template and sprite/vector dropdown choices.
- [x] Use visual color pickers; preserve hand-effect color independently of impact color.
- [x] Validate finite numbers, whole-number counts and model limits visibly, before applying edits. Accept whole-number inputs such as `2.0` correctly.
- [x] Rebuild dropdown state after Restore defaults.
- [x] Refresh the saved draft when the sound cue changes.
- [x] Hide irrelevant healing, shield, projectile steering, range and effect-strength controls for native skills where those controls do not apply.
- [x] Correct the old guidance that claimed custom skills replace the original.

## Runtime corrections

| Setting | Correction / consuming path |
| --- | --- |
| Equipped display scale | Resolve the equipped custom ID, not just the carrier kind; apply in gun, blade, shield and orbiting-flail renderers. |
| Dual wield visuals | Resolve each equipment slot independently for scale, grip inset and sprite/vector mode. |
| Grip inset and tracking | Resolve the equipped definition instead of the built-in template. |
| Sprite/vector | Honor the selected mode for held artwork as well as field items and custom projectiles. |
| Projectile scale / spin | Copy values into native and composed projectiles, preserve scale when splitting, and use that metadata in sprite and vector paths. A zero Boomerang spin no longer means a hardcoded fallback spin. |
| Pickup artwork scale | New independent persisted control for collectible artwork. It does not change the ball or pickup collision radius. |
| Effect artwork scale | New persisted control for attack, impact-particle and status-effect artwork. Physical reach remains a separate behavior setting. |
| Explosion on impact | Native optional impact explosions and composed explosions use their definition; custom explosions retain their identity for visual mode and scale. |
| Homing / return | Apply configured steering and return behavior; normal projectiles no longer inherit homing accidentally, and reflected shots target the original attacker. |
| Armor and recovery | Golden Armor reads configured shield hits. Apple reads configured healing. Recovery effects can reclaim free threads in All-Out. |
| Freeze | Composed freeze carries its configured damage multiplier and frozen-collision damage onto the affected ball. |
| Duration / count | Vampire and magnetic-field durations and Lightning Strikes count read the definition. One-shot Shotgun/Bow volleys avoid division by zero. |
| Custom trap activation | Resolve composed pickup behavior before applying native Mine behavior. |
| Impact color / shake | Native impacts read the skill's configured color and shake. Composed impact size uses the effect artwork scale. |
| Hybrid recovery | A secondary healing effect restores the attacker rather than healing the opponent it just damaged. |

Native skills retain their specialist sequences. The editor distinguishes their applicable controls from the generic composed-skill behavior model. Base artwork proportions remain defaults; the exposed scale values multiply them rather than resizing the ball or silently changing attack reach.

## Verification

- [x] Static analysis.
- [x] Simulation regressions for saved custom identity, visual mode, tracking, projectile scale/homing, Apple recovery and armor hit count.
- [x] Pixel-render regression showing increased equipped scale actually increases painted pixels for guns, swords, shields and flails.
- [x] 390px phone-layout regression including fixed labels, controls and equal aligned previews.
- [x] Existing editor save/reload and custom-skill behavior tests.
- [ ] Hands-on browser and Android visual acceptance. Automated tests are not a claim of real-device verification.

## Replay sharing added in the same pass

- [x] Saving stays local and offline.
- [x] Replay menu provides explicit Create share link; successful uploads retain both the local replay and cached short URL.
- [x] Copy share link reuses the cached URL without uploading again.
- [x] Versioned `.bw` JSON payload preserves all replay query options, including skill snapshots, Mayhem, arena and appearance settings.
- [x] Old server short links still resolve through their existing columns.
- [x] Invalid/oversized replay documents are rejected.
- [ ] Apply `supabase/migrations/020_replay_documents.sql` to the production database. This checkout does not provide a database administration connection. Until then the app reports the missing migration and keeps local replays.

The server stores the `.bw` document as JSON in the replay row behind `?r=CODE`. A standalone file download/import UI and Android file association are separate from the agreed opt-in server upload flow.
