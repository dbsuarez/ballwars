# Phase D: battle, results and replay UI

Implemented locally on 2026-11-07. No deployment or release in this pass.

## Changes

- Battle HUD uses the shared game theme and background chrome. Compact standings have beveled, ball-color frames. Live arena dimensions, renderers, controls and simulation inputs remain unchanged.
- The winner panel centers in the full available app window in both portrait and landscape. Short two-ball layouts previously let the portrait stack shrink to its content height, raising the panel above the screen center. Both orientation roots now fill their available viewport. Landscape results and cinematic overlays no longer occupy only the left arena pane.
- Winner name and result stay visible. Long details, standings and prompts scroll at native text size; Play again/Next round, Replay, Save replay, export/share and Exit remain reachable. Short landscape omits the decorative portrait to leave room for details. The original callbacks, ranking and confetti timing remain.
- Narrow landscape panels show contestants in a four-column grid and keep Pause near Leave at the top. Timer and restart stack when needed. Unstuck can become an icon-only control with its existing tooltip; narrow utility lanes wrap instead of overflowing into audio controls.
- Saved replay cards, rename dialogs and video export dialogs share game styling. Rename, import, .bw export, deletion, sharing, visibility/audio options and export/cancel behavior remain unchanged.

## Verification

**122 affected checks passed**, including real-match centering and the runtime screenshot checks. Static analysis: **no issues found**. Production-path release web build: **passed, exit 0**. Final analysis/build results, commands and log hashes are recorded in [the validation manifest](PHASE-D-VALIDATION.json). Runtime screenshots use actual Flutter widgets with bundled fonts, local in-memory fixtures and an inactive export backend. They do not use real accounts or production writes.

The new real-match regression measures the winner panel center against the app window at 360x800 and 800x360. Existing eight-ball tests continue to require an unchanged full-width portrait arena. Capture checks also verify reachable actions and centered replay/export presentation.

```powershell
flutter test test/visual/capture_battle_ui.dart
```

## Screenshots

| Screen | Phone | Short landscape | Larger frame |
| --- | --- | --- | --- |
| Battle HUD | [360x800](screenshots/phase-d/battle-360x800.png) | [800x360](screenshots/phase-d/battle-800x360.png) | [440x900](screenshots/phase-d/battle-440x900.png) |
| Winner panel | [360x800](screenshots/phase-d/results-360x800.png) | [800x360](screenshots/phase-d/results-800x360.png) | [440x900](screenshots/phase-d/results-440x900.png) |
| Scrolled result details | [360x800](screenshots/phase-d/results-tally-360x800.png) | [800x360](screenshots/phase-d/results-tally-800x360.png) | [440x900](screenshots/phase-d/results-tally-440x900.png) |
| Saved replays | [360x800](screenshots/phase-d/replays-360x800.png) | [800x360](screenshots/phase-d/replays-800x360.png) | [440x900](screenshots/phase-d/replays-440x900.png) |
| Video export choices | [360x800](screenshots/phase-d/export-360x800.png) | [800x360](screenshots/phase-d/export-800x360.png) | [440x900](screenshots/phase-d/export-440x900.png) |

[All 15 capture dimensions and hashes](PHASE-D-SCREENSHOTS.json).

## Boundaries

No simulation timing, hit logic, deterministic replay payloads, video-frame renderer, audio muxing, export visibility defaults, data schema, package, version or release-workflow changes. No new artwork, AI generation or cumulative ZIP. A local web build does not establish actual phone/browser or production acceptance. Phase E (motion, performance and remaining player screens) is next.
