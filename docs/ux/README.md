# Ball Wars game UI roadmap

Status: Phase A + B implemented and submitted for deployment/release as v1.14.61. The centered Power-up Test follow-up is submitted as v1.14.62 on 2026-11-06. Workflow completion and device acceptance remain manual. [Validation and screenshots](PHASE-A-B-REPORT.md).

Phase C is implemented locally on 2026-11-07. [Skill workbench report and screenshots](PHASE-C-REPORT.md). Phase C has not been pushed or released.

Phase D is implemented locally on 2026-11-07. [Battle, results and replay report](PHASE-D-REPORT.md). Phase E is next; Phase D has not been pushed or released.

The implementation follows [the supplied handoff](BALL_WARS_FREE_UI_REDESIGN_CODEX_HANDOFF.md). The reference checkpoint was refreshed against master v1.14.60 (`15c500d`), preserving all five existing mode entries, current settings, simulation and release workflows.

## Phase A - foundation

- [x] Shared color/typography treatments, beveled panels, background chrome, mode tiles, primary actions, section headings, icon buttons and player dialogs.
- [x] Existing fields, sliders, switches, tabs, dropdowns and validation retained through the scoped theme; no per-screen replacements of their state/controllers.
- [x] Component gallery with enabled, disabled, selected, rarity, loading, empty and error examples; keyboard/text input and switch checks.
- [x] Normal / Rare / Epic / Special use the existing rarity model.
- [x] Existing configured palettes preserved. Midnight uses the new navy arcade palette.
- [x] Widget tests, opt-in visual baselines, larger-text checks and portrait/landscape checks.
- [x] Free-tool and asset/font provenance reviewed; no new packages or paid services. [Manifest](ASSET-MANIFEST.json).
- [x] Public Credits & licenses entry with bundled font/icon notices.

## Phase B - Home and Match Setup

- [x] Home with a large Play action, mode-specific tiles, remembered last-used mode, My groups / Saved replays in one row, music, Settings and Android Quit.
- [x] User-owned illustration approved for reuse on 2026-11-06, processed locally; UI labels and controls remain native Flutter widgets.
- [x] Match Setup lineup banner, selectable fighter cards, checkmarks, selected slots, quick arena thumbnail, settings summary and Start action.
- [x] Player settings, loadout selection, arena selection and geometry dialogs share the visual theme while keeping existing choices and validation.
- [x] Per-mode settings and pickup selection retained; no changed simulation rules, currencies, levels, teams or manual combat controls.
- [x] Short-window scrolling and keyboard focus retained; the shared 440px maximum app width remains in place.
- [ ] Actual phone/browser acceptance and before/after phone performance check after publication.

## Included Power-up Test request

- [x] Independently collapsible side rails, remembered on this device.
- [x] Remove overlay clear buttons. Hold a populated slot and choose No item to remove it.
- [x] Keep utility/finisher buttons at 36px; use a centered 72px Play/Pause target for easier reach.
- [x] Center arena, status, finishers and playback as one group. Scroll short windows instead of shrinking the arena. [Preview](POWERUP-TEST-CENTERED-PREVIEW.md).
- [x] Keep the arena full width, tap-to-rearm, hold-to-choose, random initial direction and normal bounce physics. Play does not rearm automatically.

## Phase C and next visual slices

- [x] Phase C: Skill Library, Skill Editor, Ball Studio and Skill Demo. Implemented locally on 2026-11-07; [report and screenshots](PHASE-C-REPORT.md).
  - [x] Tier-aware skill frames, visibly labeled unified filters and shared game chrome/dialogs.
  - [x] Six existing editor sections and grouped controls, preserving all fields, previews and Save validation.
  - [x] Ball Studio and Skill Demo share the visual system; short windows scroll.
  - [x] 141 affected regressions passed; portrait/landscape screenshots captured at three sizes. Analysis clean.
- [ ] Phase C phone/browser acceptance after publication.
- [x] Phase D: battle HUD, results and replay presentation. [Report and screenshots](PHASE-D-REPORT.md).
  - [x] Shared game chrome and ball-color standing frames; portrait arena area preserved.
  - [x] Center win panels in the full app viewport, including short two-ball layouts and landscape.
  - [x] Scroll result details with a visible winner title and reachable playback/save actions.
  - [x] Responsive landscape contestants, pause, timer/restart and utility controls.
  - [x] Saved replay and export-dialog styling; existing replay/export choices preserved.
  - [x] 122 affected checks passed; 15 runtime captures at three screen sizes. Analysis clean and release web build passed.
- [ ] Phase D phone/browser acceptance after publication.
- [ ] Phase E (next): additional motion, measured performance polish and remaining player screens.

## Artwork and tools

Originals are unchanged. PhotoCraft cropped x=0, y=425, width=941, height=555 from the supplied Home concept. The PNG master is `processed/lobby-hero.png`; the runtime WebP is `assets/ui/lobby-hero.webp` at quality 88, 129,778 bytes. Runtime edge fading and a game-rendered loading/error fallback are retained. Concept sheets are never interactive screens.

The owner's reuse confirmation and hashes are recorded in the asset manifest. This does not assign an open-source license to the owner's artwork. PhotoCraft's installed NOTICE declares MIT OR Apache-2.0; it is only a local authoring tool and is not shipped. No ArtCraft logos are used. Existing Manrope/JetBrains Mono OFL notices and the SDK's Material Icons attribution/license are bundled and accessible from Home.

## Reproduce

Use Flutter 3.38.5, pinned by the project:

```powershell
flutter run -t tools/ux/game_ui_gallery.dart -d chrome
flutter test test/core/theme/game_ui_gallery_test.dart
flutter test test/core/theme/game_ui_gallery_test.dart --dart-define=GAME_UI_GOLDENS=true
flutter test test/visual/capture_player_ui.dart
flutter test test/visual/capture_skill_ui.dart
flutter test test/visual/capture_battle_ui.dart
```

The optional pixel comparison uses the checked-in Windows/Flutter 3.38.5 baselines. Ordinary widget interaction/layout checks run on all hosts. Refresh intentional visual baselines with `--update-goldens` and inspect the output. Capture output goes to `build/game-ui-screenshots`; committed copies and hashes are in `screenshots/` and `SCREENSHOT-MANIFEST.json`.

No cumulative ZIP is created. Source and documentation are delivered through local Git commits; deploy/release remain explicit commands.
