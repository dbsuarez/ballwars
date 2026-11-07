# Arena and ball roadmap ? 2026-10-29

> Current reconciliation (2026-11-04): this document contains historical completion claims. See the [whole-app audit](WHOLE-APP-AUDIT-2026-11-04.md#roadmap-reconciliation) and [remediation roadmap](WHOLE-APP-AUDIT-ROADMAP.md) before selecting new work. Earlier checkboxes are preserved as history.


This batch prioritizes changes that reuse the current renderer and settings. Geometry changes and recording work remain separate. No AI image generation is used.

## A. Ball appearance and demo controls (smallest implementation)

- [x] Outline HP-bar containers with one logical pixel, independent of arena zoom.
- [x] Admin HP-bar sizes Small / Medium / Large; Small preserves the previous dimensions.
- [x] Admin Ball Studio with a pinned live arena-renderer preview and Body / Face & hands / HP bar tabs.
- [x] Shared outer-glow toggle/width, hand size and Gloves / Simple circles / Mittens styles.
- [x] Eleven code-drawn expressions, including six new ones: Grinning, Angry, Dizzy, Focused, Sad and Knocked out.
- [x] Enhanced automatic expressions follow aiming, stun, overcharge and health; retain a classic-expression toggle.
- [x] Test any expression, preview ball radius/color/health and held item without modifying actual ball stats.
- [x] Remember Ball Studio preview choices and tab on this device; explicit Save persists shared appearance.
- [x] Skill Demo remembers sound, speed, facing, inspector and ball distance.
- [x] Skill Demo distance slider and Near / Mid / Far / Auto buttons; spacing stays inside the rim and avoids overlap.
- [x] Shared settings serialize, cache offline and are confirmed after server saves; failed saves keep drafts and show an error.
- [x] Migration `supabase/migrations/025_ball_appearance.sql` applied by the user. Missing-column and unconfirmed-save errors remain explicit; live production application was user-confirmed, not independently queried.
- [ ] Browser/Android hands-on acceptance.

Location: Admin Settings > Appearance > Balls > **Ball Studio**. Reset defaults changes the draft; Save publishes it. Existing glow controls remain available.

The new `ball_appearance` JSON column contains only cosmetic parameters. It does not change ball radius, collisions, skill reach, hitboxes or random draws. Match Setup still decides whether HP bars are visible. Live arena, Skill Demo, Power-up Test and the existing exported arena painter use the shared appearance settings. Cinematic finishers retain their deliberately separate character choreography; this batch does not redesign those cutscenes or the recording layout.

## B. Arena geometry and hiding spots (larger shared foundation)

- [x] Add a square outer arena alongside the circle.
- [x] Add an optional center obstacle: outlined circle or square, configurable size, no colored fill.
- [x] Reflect balls and bouncing ammunition against the same geometry; block straight projectiles and account for line of sight.
- [x] Share geometry across drawing, collision, shrinking, spawning, boundary traps, portals and physics previews; regression coverage exists. Real-device acceptance remains pending.
- [x] Replay reconstruction preserves rotation/geometry changes; post-transition state/outcome fixtures and pixel comparison of a rotated export frame pass (Batch 4).

This needs one shared geometry contract, rather than drawing a square over circular collision rules. Center walls must never count as the outer arena boundary.

## C. Threads variation and changing arenas

- [x] Threads variation starting with exactly one thread per ball.
- [x] Additional threads come only from touching the actual outer arena boundary, never center walls.
- [x] Reuse wall-claim logic, with explicit initial allocation, growth rules and per-mode settings/replay tests.
- [x] User option to cycle arena presets during a match.
- [x] Remember the interval separately per mode: default 60 seconds, minimum 30 seconds, 30-second steps.
- [x] Bound timed-match intervals through the shared rotation model and its tests.
- [x] Snapshot/reconstruct arena rotation through local/server/file replay and export (Batch 4).

## D. Arena authoring

- [x] Admin arena editor to add named arenas; see [Arena editor](ARENA-EDITOR.md).
- [x] Reuse the same map-selection dialog for users/admin. The shared chooser includes the persistent custom catalog.
- [x] Author template colors, uploaded/cropped square backgrounds, outer shape, center obstacle and native trap sets through the shared preset model.
- [x] Validate passage clearance against minimum arena scale; revision 10 uses safe non-overlapping spawns and respawns. Match Start also checks actual ball size and Cut Race maximum size.

## E. Replay / export ? last, as requested

- [x] Retain Classic video and offer Watching view with independent visible presentation choices; see the Batch 4 report.
- [x] Exclude BGM / SFX / UX controls, Unstuck, Close (X), Pause and Mayhem match buttons from recorded output. This describes excluded controls, not a change to the audio-inclusion choices.
- [x] Admin-configurable bouncing DVD-style watermark text, default `cha0s' Balls`.
- [x] Keep the bouncing export watermark separate from the existing winner-card tiled watermark.
- [x] Preserve saved-replay playback/sharing, audio choices and the existing 10-minute render warning.
- [x] Migration 028 applied (user confirmed).
- [ ] Updated device/browser playback and file-picker acceptance remains manual.

## Useful follow-ups for Ball Studio

- [x] Preview different ball looks (picture / face / both) with an actual saved ball.
- [x] Optional eye/mouth size, blink timing and pupil-follow strength using the same code renderer.
- [x] Portrait-phone preview and a six-ball visual-density preview.
- [x] Named appearance presets if multiple styles become useful.

Implemented locally on 2026-11-05. Named presets are device-local; Save publishes the applied draft through shared settings. See [Ball Studio follow-ups](BALL-STUDIO-FOLLOWUPS.md) for usage and remaining device checks.

## Verification for batch A

963 tests passed, with one opt-in performance test skipped. Analysis and the release web build pass. Phone-sized Body / Face & hands / HP bar views and the eleven-expression gallery were rendered and inspected. Tests cover shared/offline persistence, explicit missing-migration/server-confirmation failures, admin navigation and saving, retrying failed saves, actual arena settings updates, HP geometry/outline scaling, expression uniqueness, hand-size isolation from collisions, remembered demo preferences and bounded ball spacing. Long ordered-step timelines are included in the demo duration estimate while keeping the existing 45-second safety limit.

Android/browser hands-on acceptance remains unchecked. GitHub deployment completion is not monitored.

## F. Neo Threads modifiers and Mayhem expansion (2026-11-05)

- [x] Keep existing Threads and Thread Growth/Neo Threads rules unchanged when modifiers are off.
- [x] Neo Threads > Cut Race: editable target 1–1000, default 50; manual input and numeric up/down. Remember it per mode.
- [x] Separate Stay in play at zero threads toggle. On: only target wins; Off: zero threads eliminates, target or last survivor wins.
- [x] Cut Race size follows owned threads, bounded to 0.5–1.5 times selected size; the configured maximum threads is the upper endpoint. Collision body follows the visible size.
- [x] Mayhem accepts 6, 7 or 8 selected balls, preserving duration, respawns and ranking rules.
- [x] Drag balls in Power-up Test/Live Arena. Placement avoids walls and the other ball; dragging temporarily suspends simulation and preserves velocity, equipment, time and idle pinning.
- [x] Defeated balls turn into rising/fading ghosts; Mayhem/Unlimited respawn after 0.75 simulation seconds. Historical revisions retain immediate respawn.
- [ ] Manual phone checks for eight-ball density, background picking/upload, dragging and death animation.

Implementation and verification: [Gameplay and arena additions](GAMEPLAY-ARENA-ADDITIONS.md).


## Death animation emphasis (2026-11-07)

- [x] Supplied Ghost Orb artwork is 20% larger; framing compensates for its
  transparent margins so the visible round body is approximately ball-sized.
- [x] New matches use replay revision 11: six fixed simulation steps (100 ms at
  normal speed) freeze survivor movement, combat and live particle/text updates
  after a knockout, while death ghosts continue floating. Simultaneous deaths
  share one pause. Normal playback resumes automatically.
- [x] Respawn delay and ghost lifetime remain 0.75 seconds; no extra respawn wait.
- [x] Revision 10 and earlier retain their previous mechanics; revision 11 links
  round-trip. Match Setup and Power-up Test create revision 11 matches.
- [x] Ghost rendering, pause/resume, simultaneous deaths, respawn and old-replay
  behavior have regression coverage. Static analysis is clean.
- [ ] Physical phone pacing acceptance after explicit deployment.
