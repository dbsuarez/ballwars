# Batch 3: Device, browser and production acceptance

Date: 2026-11-04 (Asia/Taipei). Baseline `91ab400`, with local Batch 1/2 fixes. This report distinguishes observed acceptance from automated coverage. Shared-skill testing uses a reversible user-authorized Apple rename; no database migration, deployment, tag, published release or ZIP is part of these checks.

## Verified so far

| Check | Evidence and limits |
| --- | --- |
| Phone inventory | USB-authorized Infinix X6873, Android 16, 1224 x 2720 at density 480. Actual Chrome CSS viewport 408 x 796, device-pixel ratio 3. |
| Installed GitHub APK baseline | `com.ballwars.ballwars`, version 1.14.50, Android versionCode 1014050. User confirmed it came from GitHub. |
| Native update | Current 1.14.51 / 1014051 release APK built successfully, v2 signature valid and signer matches the installed GitHub APK. `adb install -r` succeeded. Home still listed seven saved replays. First cold launch reported 837 ms; no data clear/uninstall was used. |
| Actual stale-save protection | User renamed Apple on the PC after the native app loaded its prior library. Native Save Library was rejected with the visible changed-on-another-device/reload message rather than overwriting the server. The legacy Save Library route closes back to Settings before the failure appears; retaining that route's library draft is a separate UX follow-up. |
| Actual PC/native skill synchronization | Cold-reopening native loaded `Batch 3 sync check` for the unchanged `builtin.apple` identity. Renaming it back to Apple in the native editor persisted on the server, and the user confirmed Apple reappeared after refreshing PC. Its generated description remained unchanged. |
| Remembered native account/data | Admin settings and Skill Management remained accessible after update and force-stop/cold launch without another login. Seven saved replays remained listed. This does not prove every token-expiry/background duration case. |
| Native system Back | A confirmed unsaved Apple name draft survived keyboard dismissal; a second system Back opened Save / Discard / Keep editing. Discard returned to the library with saved Apple unchanged. |
| Native Mayhem/lifecycle | Actual six-ball square arena with center obstacle, hair, nine selected pickups, shells and arena traps completed its two-minute tally. Across about 24 seconds out of the foreground, screenshots show simulation time moving only from 1:58.3 to 1:59.6 after resuming, rather than catching up background time. |
| Native memory samples | Six-ball foreground PSS 254,495 KiB / RSS 398,336 KiB, including Graphics 113,340 KiB. After resume PSS 206,712 KiB; after match PSS 233,615 KiB. One export sample PSS 279,527 KiB. These are point samples, not a leak/thermal soak test. Android `gfxinfo` reported 1% janky frames in its 299-frame HWUI sample; that is not a Flutter raster/GPU trace. |
| Laptop viewport | User confirmed Skill Management fits the PC window with readable controls, and successfully edited/refreshed Apple there. Full independent desktop screenshot/navigation/audio inspection was unavailable. |
| Account-owned groups | User reported two groups on PC, first IT Avenue. The final native build independently loaded two groups with IT Avenue first, including its six balls. This verifies the actual account-owned list across the two clients, not just public/global settings. No group edits/deletes were needed. |
| Native codec/audio mux | Actual two-minute six-ball export with both BGM and SFX checked saved to Movies/BallWars. MP4: H.264 720x1280 at 30 fps, AAC audio, 125.666-second container, 109,722,745 bytes. Full FFmpeg decode returned success with no errors. Mean audio -25.7 dB / max -9.9 dB, so the muxed track is not silent. On-phone player confirmation is recorded separately below. |
| On-phone exported playback | User confirmed that the exported video and audio play correctly on the phone. The default player's first-use privacy consent was left to the user. This validates the generated file, not the still-unfinished watching-layout/watermark redesign. |
| Current mobile web build | Local release build served through a localhost-only USB reverse port. Home, Mayhem selection, six random contestants and Match Settings rendered with readable controls. The arena reaches the available screen width. |
| Six-ball match completion | Two-minute Mayhem reached its finisher, winner and ranked wins/deaths/HP tally. Actual held artwork, projectiles, callouts and shell effects were visible. This run used fallback for one unavailable required artwork asset. |
| Mobile live audio controls | Long-pressing BGM opened one compact popup with BGM/SFX/UX toggles and sliders, showing 100/90/90. No white-on-white action button was observed in these screens. |
| Cold browser sound | User reported that sounds start promptly during the phone test. This is user-observed audio acceptance for this run, not an instrumented latency measurement or native audio result. |
| Phone browser scheduling/memory | Five-second foreground sample: rAF interval P50/P95 about 16.7 ms; JS heap about 52 MB. These are browser scheduling and JS-heap observations, not GPU frame timing, total process/GPU memory or a leak soak test. |
| Six-ball offscreen profile | 720 simulation steps, 120 raster/readback frames. Simulation mean 0.376 ms / P95 0.848 ms; raster/readback mean 9.288 ms / P95 14.753 ms. Registered decoded frames 4,796,416 bytes; peaks 15 projectiles, 7 sources, 475 particles. Flutter test backend on Windows; do not compare as an Android FPS result. |
| Public web deployment | Entry point, version, JavaScript and Material icon font returned HTTP 200. Live version 1.14.51+11451. Live JavaScript hash differs from the local Batch 2 build; equal version text does not prove the current fixes were deployed. |
| Public database shape | Zero-row reads succeeded for `app_settings.updated_at/skill_library/ball_appearance`, `replays.replay_payload`, sprite atlas/revision columns and ball gender. This establishes exposed column/table availability, not complete migration history, RLS correctness or trigger installation. |

## Issues and remaining acceptance

- The initial missing-artwork warning was traced to Energy Wave's intentional `ballwars:held:none` presentation sentinel. All ten public custom sheet URLs and referenced atlas entries existed. The shared active/full reference collection now excludes this non-asset value, preserving actual asset validation. The regression test and actual shared-library observation pass (14 dependencies instead of the false fifteenth). The final phone Chrome build subsequently ran a match without the warning or fallback (`build/batch3-web-final-no-fallback.png`).
- Match Setup currently has Gameplay and Appearance tabs, and explicitly omits Audio in source. The old roadmap claim that all three audio channels are exposed in Match Setup is not true. The live arena popup is verified; setup audio parity remains open.
- Desktop browser control failed to initialize twice, including after a kernel reset: `failed to write kernel assets: The system cannot find the path specified. (os error 3)`. Laptop browser navigation and signed-in PC editing cannot be claimed from widget tests or the phone alone.
- Native update, background/resume, six-ball play, point-in-time memory samples and actual codec/playback checks passed. Native live cold-first-shot latency remains unmeasured: this account's native BGM/SFX/UX preferences were muted and were preserved. A long thermal/memory soak and Flutter GPU trace are not claimed.
- Skill edits in both directions, a deliberately stale shared-settings save and the account-owned group list are verified above. Account switching/offline transport failure tests remain automated coverage, not destructive live account/data experiments.
- Independently verify security-trigger migrations 026/027 through authorized database inspection when available; zero-row public reads cannot establish those triggers. [Read-only SQL checks](BATCH3-PRODUCTION-VERIFY.sql) are prepared. No migration is applied by this report.
- After a requested deployment, verify the current bundle/artifact rather than only its version label. GitHub workflow runs are not monitored.

## Native build diagnosis

The package's local build number 11451 is lower than the installed GitHub APK's 1014050. The existing release workflow already uses `major * 1000000 + minor * 1000 + patch`, so the acceptance build uses `--build-name 1.14.51 --build-number 1014051` without editing `pubspec.yaml`.

The first local attempts failed from an 8 GB Gradle/Kotlin heap exhausting Windows commit space and Kotlin incremental caches spanning C: dependencies and D: source. Bounded Gradle memory, one worker and explicit Kotlin project arguments address that local setup. A subsequent release compile exposed stale generated plugin registration containing dev-only plugins: Flutter 3.38.5's `--no-pub` skips platform tooling regeneration. The corrected build passed in 234 seconds through Flutter with pub/tooling regeneration and release-only plugin registration; no generated Java was hand edited. APK SHA-256: `070b3f13389b21a424f59ee2bca13e9d2221d92440b1b69fbda1c58628d1e172`.

Do not uninstall the existing app to work around version/signature failures. Check the new artifact's version and signing certificate against the installed APK, then use a data-preserving update only if compatible. The installed public signer SHA-256 is `e5fe964d0cb9367e59a3b082bf769b3d6737423b43e25de3700260e7798a4ec8`.

## Reproduce the available checks

From the repository root:

```powershell
python tools/verify_public_production.py
flutter test --dart-define=PROFILE_SIX_BALL=true test/performance/six_ball_artwork_profile_test.dart
python tools/serve_web_acceptance.py
adb reverse tcp:8334 tcp:8334
# Open http://127.0.0.1:8334/ballwars/ in phone Chrome, using an existing release build.
adb forward tcp:9223 localabstract:chrome_devtools_remote
node tools/probe_android_web.mjs
```

Use the repository's pinned Flutter 3.38.5, not the machine's older default. The web probe reads only the visible localhost test tab's viewport/performance data; it never reads cookies, account storage or unrelated tabs. Remove these exact ADB forwards/reverse rules and stop the task-owned local server after verification.

Local screenshots/logs are under `build/batch3-*`. Small public probe results are retained under `docs/performance/`; APKs, personal screen captures and device identifiers are not added to the repository.

## Documentation reconciliation

Historical phase counts/test totals remain historical. The Skill Management roadmap no longer calls Phase 9 or the entire system complete while replay targeting, rotation, empty pickups and watching-layout parity remain open. Square geometry, center obstacles, Thread Growth and live rotation are marked implemented in the arena roadmap; changing-arena replay reconstruction remains unchecked. Obsolete Phase F-pending/four-tab text is updated to current implementation. The [whole-app roadmap](WHOLE-APP-AUDIT-ROADMAP.md) remains the completion ledger.

## Final software checks and requested polish

- Full suite: **1,643 passed, one skipped** (`build/batch3-full-tests.log`); source analysis clean (`build/batch3-analysis.log`). The opt-in six-ball profile passed separately.
- Final release web build passed (`build/batch3-web-final.log`); final native release build passed in 133 seconds (`build/batch3-android-final-verified.log`).
- User-requested **My groups / Saved replays** shortcuts share one equal-width row. Saved replays remains accessible when empty, with a count or visible read/retry message. Actual Flutter font/layout previews at 320 and 408 pixels passed and were visually inspected; narrow labels wrap rather than shrink.
- Final APK signer matches the original GitHub APK; SHA-256 `3b7e8168a808545ace971be36f4ae3287ddfb6719543e25448c1acf3a49e4a30`. No version source file was bumped and no GitHub release was published.
- Final APK was installed successfully as a data-preserving update, and its home row was inspected on the actual phone. Seven saved replays remained accessible.

The user reconfirmed during this batch that the exported DVD watermark and watching UX are still wrong. These remain **Batch 4 work**, not completed by successful encoding/playback: remove the hardcoded `dbsuarez.github.io` export watermark in favor of an admin-configurable DVD-style text defaulting to `cha0s' Balls`, and reproduce the watching presentation while excluding interactive controls.

## Closure and manual handoff (2026-11-04)

Coding and available acceptance work are finished. The user requested that remaining hands-on checks be handed over rather than delaying Batch 4. See the numbered manual checklist in [the roadmap](WHOLE-APP-AUDIT-ROADMAP.md): five production trigger attachments, native cold audio, remaining laptop navigation/audio and future deployed-artifact confirmation. These remain unverified, not silently passed.

The user supplied the three production function definitions. Their immutable sprite revision guard, serialized replay budget and per-owner/group limit locks match migrations 024/026/027. Trigger attachments/enabled state still require the final five-row SQL result.

The final phone browser match verified the sentinel fix without fallback. Batch 4 will preserve the existing export while providing independent visibility options for the saved video; live match preferences must remain unchanged. Match Setup audio parity and legacy Save Library draft retention are explicitly carried forward as coding follow-ups.

## Follow-up implementation and SQL confirmation

The supplied `Supabase Snippet Untitled query.csv` confirms all five expected triggers are installed, enabled (`O`), and use the expected functions. Together with the previously supplied function bodies, the requested trigger check is complete.

Match Settings now includes Audio beside Gameplay and Appearance. It reuses the live popup's BGM/SFX/UX switches and volume sliders, including their existing preference persistence. Save Library now awaits its persistence callback without closing the library; failed writes retain the draft and offer Retry. Route-only callers without a persistence callback retain their existing result-return behavior.

Regression coverage includes both settings layouts, failed-save/retry retention, existing editor workflows, audio popup controls and replay links: 86 tests passed. No production push/deployment/release is implied.
