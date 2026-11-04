# Batch 4: Replay and export

Updated: 2026-11-04. Master checklist: [whole-app roadmap](WHOLE-APP-AUDIT-ROADMAP.md).

## Coding completed

- [x] A02: version targeting rules; new matches use revision 7, historical revisions use legacy nearest-target behavior. Accept previously generated revision 6 links. [Compatibility policy and historical limits](REPLAY-COMPATIBILITY.md).
- [x] A03: snapshot rotation, restore it when opening and exporting, render the simulated theme/shape and transition feedback. Saved/server reconstruction matches post-transition state and final outcomes; exported post-transition frame matches live rendering pixel-for-pixel.
- [x] A04: explicit empty built-ins and custom-only loadouts survive local/server/file round trips; the custom skill actually spawns without enabling built-ins.
- [x] A13: missing/unsupported/invalid links show explanations. Connection failures offer Retry; ordinary app startup does not show a replay error.
- [x] Keep Classic video and add Watching view with a full-width arena and optional standings/item indicators. No clickable player controls are captured.
- [x] Independent video choices: results/finishers, ball names, pictures, health, scores/timer/standings, equipped items, callouts, arena text and bouncing watermark. Live preferences and simulation inputs stay unchanged.
- [x] Hide names in arena and closing scenes, including fallback initials; hide pictures in arena and closing scenes. Rendering regressions cover these combinations.
- [x] Keep independent BGM/SFX choices in the Audio tab. Video choices and audio selections are remembered for subsequent exports.
- [x] Admin video watermark has its own saved setting, default `cha0s' Balls`; winner-card branding remains separate. Missing migration/ignored writes fail explicitly.
- [x] Saved Replays imports portable `.bw` JSON files, keeps them locally, exports them again and still offers optional server sharing. File-format/size errors are visible and preserve existing saves. Platform writers follow the existing web download/Android file-picker adapters.
- [x] Arena-only exports can omit results/finishers without changing simulated match duration. Existing 10-minute confirmation and codec/audio pipeline remain in place.

## How to use

Save Video opens Video and Audio tabs. Classic video retains the existing composition. Watching view puts the arena across the video width and displays only the selected information below it. Uncheck Results and finishers for an arena-only clip. Turn off names and pictures without changing how you play the live match.

Saved Replays has an Import .bw replay action in its toolbar and Save .bw file in each replay's menu. Importing does not upload anything. Create share link remains the explicit optional server action.

Admin Settings > Appearance > Watermarks includes Bouncing video watermark and Save video watermark. Users may omit that watermark from their own exports.

## Database action required

- [ ] User applies `supabase/migrations/028_export_watermark.sql`, then reloads settings before saving a custom video-watermark value. The default video watermark works before migration; customization reports the missing migration instead of silently failing.

## Verification

- [x] Focused replay/export, rendering/privacy, file/recovery, targeting and watermark persistence tests passed (95 checks before the additional export-parity fixture).
- [x] Actual exported post-rotation frame compared against live rendering, separately passed.
- [x] Runtime-rendered mobile options and watching/arena-only frames visually inspected; real game font/theme loaded for the options preview. A narrow-phone dropdown overflow was fixed.
- [x] Final full suite: 1,659 passed, one skipped (`build/batch4-final-full-tests.log`), plus the subsequently added exported-frame parity fixture passed separately. Full source/test/tool analysis clean (`build/batch4-final-analysis2.log`). Release web build passed; signed Android release build passed in 122 seconds.
- [ ] Manual updated web/Android export playback and file-picker confirmation, handed to user; not a coding blocker and not claimed from mocked transport tests.

## Release boundary

Completed earlier audit fixes were pushed as `26bdc77` with tag `v1.14.52`, triggering deployment and signed APK publication. Pre-release suite: 1,645 passed, one skipped. GitHub workflows were deliberately not monitored. Batch 4 is now submitted for deployment/release as v1.14.53 on 2026-11-05. The master/tag pushes trigger GitHub workflows; successful production publication is not claimed without manual verification.

## User's remaining checks

1. Apply migration 028 and confirm a custom video watermark saves/reopens.
2. Export Watching view with names/pictures off. Check the video (including closing scenes) while live preferences stay on.
3. Export an arena-only clip with all optional layers and results off. Confirm BGM/SFX inclusion matches your choices.
4. Export Classic video too; check playback/audio on browser and Android.
5. Save a .bw file, transfer it between PC/phone, import it in Saved Replays and play it. Optionally create a short server share link.

Existing Batch 3 cold-native-audio/laptop/deployed-artifact checks remain in the master checklist. No ZIP or automatic GitHub monitoring is part of this work.

## Build artifacts

- Web: `build/web` (release build, base `/ballwars/`).
- APK: `build/app/outputs/flutter-apk/app-release.apk`, versionName 1.14.52, versionCode 1014052. This local APK contains the subsequent Batch 4 work; the earlier published tag has the same base version and does not contain these changes.
- APK SHA-256: `603708c6daa9d3890f29f026eaa154fef5882e281f361bdf306ef0736edcd481`.
- APK signature verification passed; signer matches the existing release certificate (`e5fe964d0cb9367e59a3b082bf769b3d6737423b43e25de3700260e7798a4ec8`). No device installation performed for this build.
- Runtime visual review captures remain local under `build/batch4-*`; no personal screenshots or generated ZIPs were added.

Coding and automated verification are complete. Remaining unchecked items are explicitly user-owned migration/device acceptance, not unfinished implementation. Historical provenance limitations are documented in the compatibility policy rather than hidden by a completion claim.

Deployment submission: Batch 4 changes are included in the v1.14.53 master/tag delivery. The local APK installed on the phone earlier is the validated 1.14.52 Batch 4 build; CI builds the published update as 1.14.53 / 1014053.
