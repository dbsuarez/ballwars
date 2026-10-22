# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Ball Wars is a Flutter app (web first, also iOS/Android) that simulates "ball battles": 2–4 custom balls bounce around inside a circular arena, each one projecting a fan of lines to the rim. Opponents cut those lines, and a ball is out once all its lines are cut. Rendering is plain Dart plus `CustomPainter`; the spec explicitly says **not** to use the Flame engine. The only non-SDK runtime dependency is `file_picker`. Images are handled as raw `Uint8List` bytes, never `dart:io` `File`, so they work on web.

Design docs (read them before larger changes):
- `docs/CLAUDE_CODE_BALL_WARS_SPEC.md`: the original full spec (directory layout, UI, theme).
- `docs/superpowers/specs/2026-09-21-ball-wars-mobile-sharing-design.md`: mobile/responsive layout, the **determinism** requirement, and the planned sharing/gallery feature.
- `docs/superpowers/plans/2026-09-21-ball-wars-core-simulator.md`: the implementation plan.
- `docs/psuedocode.txt`: reference pseudocode for the thread/line-cutting game loop that the current mechanics follow.
- `docs/output_frames/` (gitignored) and `docs/fame_1597.jpg`: frames from the reference video, which is the source of truth for mechanics and look.
- `docs/reference_video_analysis.md`: frame-by-frame findings from that video (core mechanic, physics gaps, effects still to build).

## Commands

```bash
flutter pub get
flutter run -d chrome                 # primary target
flutter analyze                       # lints: package:flutter_lints/flutter.yaml
flutter test                          # all tests
flutter test test/features/arena_simulation/application/match_simulation_controller_test.dart
flutter test --plain-name "determinism"   # tests whose name contains this text
flutter test integration_test/video_export_test.dart -d <android-device-id>   # real MediaCodec encode on a device
#   add --dart-define=KEEP_VIDEO=true to save the result to the phone's Movies/BallWars
```

Android releases: pushing a tag `v*` runs `.github/workflows/release-apk.yml`. It builds an APK signed with the release key from the `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` repository secrets, and attaches it to a GitHub Release. Locally the key lives in `android/upload-keystore.jks` plus `android/key.properties` (both git-ignored; without them release builds fall back to the debug key). Never change or lose that key, or installed copies can't be updated.

Deployment: `.github/workflows/deploy-pages.yml` runs the tests, builds web with `--base-href /<repo>/` and publishes to GitHub Pages on every push to `master`. Under Git Bash, building locally with a base href needs `MSYS_NO_PATHCONV=1`, otherwise `/ballwars/` gets rewritten into a Windows path.

## Architecture

The code is organized by feature under `lib/features/<feature>/{domain,data,application,presentation}`, with shared theme, widgets and utils in `lib/core/`. `test/` mirrors `lib/`. There is no state-management package: screens own their controllers and call `setState`. `app.dart` creates one in-memory `LocalBallRepository` (it starts with preset country balls) and passes it to the screens through their constructors. Navigation goes Home → `BallLibraryScreen` / `MatchSetupScreen` → `ArenaBattleScreen(config: MatchConfig)`.

### Simulation loop (arena_simulation)

- `ArenaBattleScreen` owns a `Ticker`. On each frame it calls `MatchSimulationController.tick(realDt * speedMultiplier)`, reads `controller.state`, and repaints through `ArenaCanvas` → `ArenaPainter` (`shouldRepaint` always returns true). The screen also handles UI-only end-game behavior: the loser dissolve animation and `WinnerModal`. Slow motion is decided by the controller (`MatchStatus.slowMotion`), and the screen only shows the badge. When a match restarts, `_skipNextDelta` resets the timing so the next frame doesn't compute a huge dt.
- `MatchSimulationController` holds all match logic. It uses a **fixed timestep** (1/60 s, accumulator, at most 10 steps per frame). Each step runs in this order: free the slots of lines deactivated from outside → integrate positions and wall bounce (`ArenaPhysicsEngine`, where wall hits claim slots) → ball-ball collisions (elastic directions, only `collisionSpeedTransfer` of the speed exchange) → move line endpoints to their owners → cut lines → elimination (with a tie-break so a match always has a winner) → win check / slow-motion status. The processing order of the balls rotates every step. Each match also rotates the layout and draws start distance, speed and tilt per ball, all to keep every contestant's odds equal. Check any change against a win-rate-by-start-position probe over many seeds; the numbers are in `docs/reference_video_analysis.md`.
- **Rim slots and lines** (`domain/fan_line.dart`, rules in the controller's class doc). The rim has `kRimSlotCount` (180) fixed slots, each free or owned by one ball, and the controller tracks ownership in `_slotOwners`. Each owned slot is a `FanLine` from its rim anchor to the owner's center, and `ball.fanLines` holds only the lines the ball currently owns. An opponent's *body* overlapping a line cuts it and frees the slot. A wall hit on a free slot claims the free run from the contact point to the ball's own nearest line. A ball with no lines is eliminated. These rules were worked out from the reference video; see `docs/reference_video_analysis.md` before changing them. Its notes also show that "beam mode", "two-blade fans" and "fan aimed at the opponent" from the older catalog aren't separate mechanics.
- `SimulationState` is a snapshot handed to the UI. It exposes the controller's **mutable** ball, particle and floating-text objects directly; nothing is copied.
- Leftover code from the earlier designs is still in place: `TerritoryEngine` (360 rim sectors) is rebuilt from the active fan lines in `_createLegacyTerritoryForCompat()` only so that the territory-based tests and the scoreboard keep working. `thread.dart` is the model from the pseudocode and nothing references it any more. Keep this in mind before deleting either one or depending on it.

### Determinism

All simulation randomness must come from the match's `SeededRandom` (`core/utils/seeded_random.dart`), which the controller creates from `seed` (by default the current time). Tests pass explicit seeds and check that the same seed produces the same state (`match_simulation_controller_test.dart`). Any new random behavior should use the controller's `_rng` instead of `math.Random()`, and only draw from it *inside simulation steps*, never per rendered frame. Then the outcome depends only on the step sequence, not on the frame rate. Replays depend on this: `controller.seed` exposes the seed actually used.

### Video export and replay links (replay_export)

`ReplayVideoExporter` re-runs a match from `(contestants, seed)` off-screen at 30 fps. It draws 720x1280 frames with `ReplayFramePainter` (9:16 layout like the reference, reusing `ArenaPainter`) and feeds RGBA frames to a `VideoExportBackend`. `createVideoExportBackend()` picks the backend per platform:
- **Android** (`AndroidVideoExport`): a method channel `ballwars/video_export` into `android/app/src/main/kotlin/.../ReplayVideoEncoder.kt`. It encodes with MediaCodec H.264 plus MediaMuxer, converts RGBA→YUV420 in Kotlin, and runs on a background thread in `MainActivity`. It saves to the gallery (Movies/BallWars) via MediaStore, which needs Android 10+.
- **Web** (`WebVideoExport`, via `dart:js_interop`): `web/video_export.js` (`window.ballwarsVideo`) encodes with WebCodecs and muxes with the vendored `web/vendor/mp4-muxer.js` (MIT, v5.2.2; upstream is deprecated in favor of Mediabunny), then downloads the MP4 or opens the share sheet. `web/index.html` loads both scripts.
- **Elsewhere** it returns null, which hides SAVE VIDEO.

`ReplayLink` builds and parses share links: `<app>?seed=..&speed=..&balls=p.<presetId>,c.<base64 json>`. These are plain query strings, so there's no `#` and no server routing to set up on GitHub Pages; legacy `#/replay?..` links still parse. The home screen opens a link found in `Uri.base` at startup. Presets are referenced by id from `LocalBallRepository.presets`, so keep those ids stable. Uploaded ball images don't travel in links.
