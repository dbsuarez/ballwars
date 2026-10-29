# Arena and ball roadmap ? 2026-10-29

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

- [ ] Add a square outer arena alongside the circle.
- [ ] Add an optional center obstacle: outlined circle or square, configurable size, no colored fill.
- [ ] Reflect balls and bouncing ammunition against the same geometry; block straight projectiles and account for line of sight.
- [ ] Keep drawing, collision, shrinking, spawn placement, boundary traps, portals and physics previews in agreement.
- [ ] Preserve old replay geometry and add deterministic collision tests before enabling these shapes.

This needs one shared geometry contract, rather than drawing a square over circular collision rules. Center walls must never count as the outer arena boundary.

## C. Threads variation and changing arenas

- [ ] Threads variation starting with exactly one thread per ball.
- [ ] Additional threads come only from touching the actual outer arena boundary, never center walls.
- [ ] Reuse existing wall-claim logic, with explicit initial allocation, growth rules and per-mode settings/replay tests.
- [ ] User option to cycle arena presets during a match.
- [ ] Remember the interval separately per mode: default 60 seconds, minimum 30 seconds, 30-second steps.
- [ ] For timed matches, validate the maximum against half the total time rounded to the nearest 30 seconds. Decide how to handle matches too short to permit even the minimum.
- [ ] Define what changes with the preset (decoration, arena-only traps and active hazard cleanup), and snapshot the sequence for replays.

## D. Arena authoring

- [ ] Admin arena editor to add named arenas.
- [ ] Reuse the same map-selection dialog for users/admin; new maps remain user-selectable.
- [ ] Author background/decorations, outer shape, center obstacles and associated traps through the shared geometry/preset model.
- [ ] Validate safe spawning, minimum passage widths and shrinking before saving a map.

## E. Replay / export ? last, as requested

- [ ] Capture the actual watching layout and visible match presentation, rather than the current separate export composition.
- [ ] Exclude BGM / SFX / UX controls, Unstuck, Close (X), Pause and Mayhem match buttons from recorded output. This describes excluded controls, not a change to the audio-inclusion choices.
- [ ] Admin-configurable bouncing DVD-style watermark text, default `cha0s' Balls`.
- [ ] Keep the bouncing export watermark separate from the existing winner-card tiled watermark.
- [ ] Preserve saved-replay playback/sharing, audio choices and the existing 10-minute render warning.

## Useful follow-ups for Ball Studio

- [ ] Preview different ball looks (picture / face / both) with an actual saved ball.
- [ ] Optional eye/mouth size, blink timing and pupil-follow strength using the same code renderer.
- [ ] Portrait-phone preview and a six-ball visual-density preview.
- [ ] Named appearance presets if multiple styles become useful.

These are suggestions for later, not promises marked complete by this batch.

## Verification for batch A

963 tests passed, with one opt-in performance test skipped. Analysis and the release web build pass. Phone-sized Body / Face & hands / HP bar views and the eleven-expression gallery were rendered and inspected. Tests cover shared/offline persistence, explicit missing-migration/server-confirmation failures, admin navigation and saving, retrying failed saves, actual arena settings updates, HP geometry/outline scaling, expression uniqueness, hand-size isolation from collisions, remembered demo preferences and bounded ball spacing. Long ordered-step timelines are included in the demo duration estimate while keeping the existing 45-second safety limit.

Android/browser hands-on acceptance remains unchecked. GitHub deployment completion is not monitored.
