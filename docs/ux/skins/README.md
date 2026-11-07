# Selectable UI skins

Settings > Appearance > UI Skin is available without an administrator login.
Choose Classic Arcade or Battle Garage. The active checkmark confirms a completed
local save; an unsuccessful write keeps the previous skin and shows an error.
The choice survives restarts on this device/browser profile. It does not change
shared administrator settings, match presets or other devices.

Classic Arcade remains the default, including existing configured palettes.
Battle Garage uses the FigCraft concept's charcoal/cyan palette, cut-corner
panels, Inter typography, subtle workshop grid, and exported raised button
artwork with normal, pressed and disabled states. Native Flutter controls retain
keyboard focus, semantics and actual actions. Settings, dialogs, workbenches,
results and other routes inherit the selected theme. Skill rarity colors remain.
Switching back restores Classic. Existing navigation and screen layouts remain;
this is a selectable skin rather than a pixel-exact replacement of every concept
board. No simulation, collision, arena dimensions or replay format changed.

## Source assets

Editable source: [Battle Garage FigCraft document](../figcraft/Ball-Wars-Arcade-Concept.figcraft).
Runtime PNG copies: assets/ui/skins/battle-garage. No AI generation or raster
editing was performed for this integration. Supplied originals remain intact.
Inter is bundled with its unmodified SIL OFL notice and registered in Credits &
licenses. Preview thumbnails show the actual implemented Home screens.

## Verification

- Persistence, failure/retry and device-local storage checks.
- Public settings selection and contrasting native action button checks.
- Actual Home rendered at 390 x 844 in both skins.
- Workbench at 320 x 740 and 800 x 360, with text drafts retained during switching.
- Existing palette, icon-role, lobby navigation and admin settings regressions.

[Screenshots](screenshots) are runtime Flutter captures, not concept mockups.
Reproduce: flutter test test/core/theme/ui_skin_test.dart --dart-define=SKIN_SCREENSHOTS=true

## Results

- 34 focused checks passed, including app-wide route retention, startup-read
  race, save/retry, settings, motion, palettes and license notices.
- Final nine skin checks and runtime screenshot capture passed.
- Flutter analysis: no issues.
- Release web build: passed with Flutter 3.38.5, --no-wasm-dry-run.
- The attempted serial full suite reached 756 passing checks before Windows
  exhausted memory and the Dart VM crashed. Its one earlier failure was the
  license test's old expected font list; adding Inter fixed it, and the focused
  license checks passed. This is not recorded as a full-suite pass.

Seven screenshots were visually inspected: Home in both skins, narrow and
short-landscape workbenches in both skins, and the public selector. The selector
previews come from the actual implemented Home screens rather than design boards.

Physical phone acceptance remains manual. No deployment, tag, release or device
installation is included in this change.


### Subsequent full-suite closure

The earlier memory-limited run is now superseded by the completed
[2026-11-07 full regression](../../FULL-REGRESSION-2026-11-07.md): 1,787 passed,
one existing opt-in profile skipped, zero failures. It used sequential process
batches and covered every ordinary test file.
