# Whole-app audit remediation roadmap

Updated: 2026-11-04. Baseline: `91ab400`, v1.14.51. Findings and evidence: [whole-app audit](WHOLE-APP-AUDIT-2026-11-04.md).

## Audit completed

- [x] Inspect current checkout and preserve unrelated local deletions.
- [x] Review all major feature areas and reconcile the older plans against current source.
- [x] Run the existing suite: 1,610 passed, one skipped.
- [x] Analyze source/test/tool directories: no issues.
- [x] Build release web with full HEAD artwork revision.
- [x] Run browser download JavaScript harness: one passed.
- [x] Reproduce ten underlying defects/ambiguities with isolated local probes.
- [x] Document 13 actionable findings, evidence, acceptance criteria and verification limits.

## Batch 1: Persistence and account recovery

- [x] A01: Explicit durable replay-write failure and retry; never report a save that did not persist.
- [x] A05: Retry failed adoption and scope adoption state to source/target account identities.
- [x] A06: Recognize browser/client network failures without hiding permission/schema errors.
- [x] A07: Return fresh server groups when only replaceable-cache writes fail.
- [x] A08: Isolate admin-wide caches across accounts and logout transitions.
- [x] A09: Detect conflicts or update only changed shared-setting fields across devices.
- [x] Convert observations to desired-behavior regression tests; rerun appropriate existing checks.

Implementation and verification: [Batch 1 report](BATCH1-PERSISTENCE-RECOVERY-2026-11-04.md). Device/production acceptance remains in Batch 3.

## Batch 2: Skill editor and stable identity

- [x] A10: Carry stable skill identity/presentation for winning moves; support identical display names.
- [x] A11: Guard library restore persistence with visible error and retry handling.
- [x] A12: Save/Discard/Keep editing on dirty editor exit, including system back.
- [x] Verify built-in/custom save/reopen, native skills, preview/live test and finisher identity together with regression/widget tests; hands-on acceptance remains Batch 3.

Implementation and verification: [Batch 2 report](BATCH2-SKILL-EDITOR-IDENTITY-2026-11-04.md).

## Batch 3: Hands-on acceptance and current documentation

Status: coding and available acceptance checks finished; remaining manual acceptance handed to the user on 2026-11-04. Unchecked manual checks below do not block starting Batch 4 and are not claimed as passed.

- [x] Phone browser visual/navigation/audio checks; laptop editor readability and navigation confirmed by the user.
- [x] Actual signed Android update, background/resume, six-ball match, sampled memory and video codec/playback checks.
- [x] Cross-device remembered session, account-owned groups, skill synchronization in both directions and stale-save conflict rejection.
- [x] Public deployment version/assets/schema columns inspected; three production function definitions supplied by the user match migrations 024/026/027.
- [x] Replace stale historical completion claims with evidence-backed feature/acceptance status.
- [x] Actual phone Chrome six-ball match/finisher/tally and compact BGM/SFX/UX popup inspected; user reports prompt browser audio.
- [x] Current signed APK built and installed as a matching-signer, data-preserving update: 1.14.51 / 1014051.
- [x] Actual Android system Back prompts Save / Discard / Keep editing on a dirty skill; test draft discarded without saving it.
- [x] Actual Android H.264/AAC export fully decoded and user-confirmed video/audio playback; watching UX/watermark remains Batch 4.
- [x] My groups / Saved replays share one home row; 320/408-pixel previews and final installed APK inspected.
- [x] Resolve false missing-artwork warning from the intentional no-held-artwork sentinel; final phone Chrome match verified without fallback.
- [x] Final software verification: 1,643 tests passed, one skipped; analysis clean; release web and APK builds passed.

Evidence and limits: [Batch 3 report](BATCH3-ACCEPTANCE-2026-11-04.md).

### User's remaining manual checklist

Reply with each number and Pass / Fail (plus what happened if it failed):

1. [x] **Production triggers:** run [read-only SQL](BATCH3-PRODUCTION-VERIFY.sql) and share its final five-row result. Each expected trigger should be installed, enabled (`O` or `A`), and attached to the expected function. Confirmed from `Supabase Snippet Untitled query.csv`: all five installed, enabled O, correct functions; function bodies also confirmed.
 - User answer: Check Supabase Snippet Untitled query.csv
2. [ ] **Native cold audio:** enable the audio you want, fully close/reopen the Android app, start a match and confirm countdown/first-shot audio starts promptly. Browser audio and exported-video audio already passed.
3. [ ] **Laptop browser:** check match setup, live arena, audio controls and replay navigation for readability, working buttons and prompt audio. Skill Management readability/editing already passed.
4. [ ] **After a future deployment:** confirm the published web app and APK contain these fixes. Local builds passed; these changes have not been pushed/deployed. No GitHub deployment monitoring is required.

### Coding follow-ups carried into Batch 4

- [x] Add the missing Match Setup Audio tab/control parity; Gameplay/Appearance/Audio now share the existing persistent BGM/SFX/UX controls.
- [x] Keep Save Library open while persisting through the existing save callback; failures retain the draft with a visible error and Retry, and duplicate saves are disabled while pending.

## Batch 4: Replay and export last

Coding completed locally, 2026-11-04. [Implementation, usage and manual checklist](BATCH4-REPLAY-EXPORT.md). Submitted for deployment/release as v1.14.53 on 2026-11-05; production workflow completion remains a manual check.

- [x] A02: version targeting and document recoverable historical behavior/limitations, with fixtures.
- [x] A03: preserve rotation through saved/server replay and video; post-transition state/outcome and exported-frame parity tests.
- [x] A04: explicit empty/custom-only replay persistence and actual custom-only spawning.
- [x] A13: visible missing/invalid/unsupported links and retry for transport failures.
- [x] Preserve Classic video and offer Watching view, excluding interactive controls.
- [x] Independent saved-video visibility choices without changing live gameplay preferences, including optional results/finishers.
- [x] Admin-configurable bouncing video watermark, default `cha0s' Balls`, separate from winner-card branding.
- [x] Portable .bw file import/export UI and optional existing server sharing.
- [x] Preserve BGM/SFX selection and the 10-minute warning; arena-only duration regression covered.
- [x] Final software verification and builds: 1,659 full-suite tests passed, one skipped; additional export-frame parity test passed; analysis clean; release web and signed APK builds passed.
- [ ] User applies migration 028 for custom watermark persistence and performs the listed updated video/file-picker checks.

## Flame rendering feasibility study (after correctness fixes)

This is an experiment, not approval to migrate engines. Keep the current renderer until measured evidence supports a change. Do not start the experiment during Batch 2.

- [ ] Use a separate branch/worktree after preserving the current audit fixes; never overwrite unrelated work.
- [ ] Feed the existing simulation state to a small Flame renderer. Keep physics, targeting, damage, fixed-step timing and seeded randomness in the current simulation.
- [ ] Render six balls, equipped/dual-wield weapons, slash VFX, animated effects, projectiles and center obstacles, including shrinking/changing arenas.
- [ ] Use the same recorded states/seeds for visual correctness, layering, scale, mirroring and replay/export comparisons.
- [ ] Measure release-mode frame times, memory, cold loading and smoothness on the actual Android phone and browser.
- [ ] Compare maintainability: identify custom infrastructure genuinely removed, dependency/adapter cost and offscreen export support. Wrapping ArenaPainter alone is only an integration smoke check.
- [ ] Write a go/no-go report with evidence and migration cost. Keep the current renderer if gains are not worthwhile; if justified, propose incremental rendering-only migration with fallback.

Reference: [Flame game/rendering documentation](https://docs.flame-engine.org/latest/flame/game.html). No Flame dependency or engine migration is included in the current audit remediation batches.

## Separate future feature

- [ ] Persistent named-arena editor/catalog with safe geometry/trap validation. Existing user/admin selection and geometry dialogs already exist; reuse them.

Completed implementation boxes reflect the local remediation batches and their linked verification reports. No release/deployment is implied by a passing local check.
