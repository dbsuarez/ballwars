# Phase E: motion, accessibility and remaining player screens

Implemented locally on 2026-11-07. No push, deployment, APK or release in this pass.

## Changes

- My Groups, its ball editor, Settings and Power-up Test share the game theme. Group panels use the shared beveled frame. Existing authentication, data writes, uploads, settings fields and editor callbacks remain.
- Settings tab labels scroll instead of clipping. The existing music-save regression now brings Audio into view before tapping; the save assertions are unchanged.
- Menu entrances are one-shot 160 ms fades with a 6 px slide. Selected panel feedback settles in 180 ms. Existing native route/sheet exit transitions remain. No new looping particles or backdrop animation.
- Reduced motion shows new entrances immediately and removes their translation. The tree stays stable so toggling reduced motion does not discard text or keyboard focus. Empty-state scaling and winner entry/confetti also respect the platform preference.
- Winner confetti runs only while effects are enabled; an effects-off result no longer runs its hidden 13-second confetti ticker. Existing normal-motion duration and result callbacks remain.
- Static backdrop art and gradients have a separate paint layer. Home artwork requests a viewport/device-pixel-ratio decode width capped at 940; the supplied original and its runtime file are unchanged.
- Full-width arenas, the centered results fix and 72 px Power-up Test Play/Pause remain. Gameplay clocks, simulation, replay data and export choices are untouched.

## Measured local checks

[Performance measurements](PHASE-E-PERFORMANCE.json): with 40 changing child frames, the old shared-layer composition repaints the actual stadium painter 40 times. The isolated composition performs zero additional background repaints and reuses the layer 40 times. This measures paint invalidation, not phone GPU performance or FPS.

Home decode requests at a 360 px viewport are 360 px at 1x instead of 940 px, and remain capped at 940 px at 3x. The estimated decoded-pixel budget at 1x is about 15% of the old request; actual browser/phone memory is not measured.

## Verification

Full serial suite: **1,770 passed / one existing opt-in skip**. Final focused/visual suite: **54 passed**, including unchanged gallery pixel baselines; additional 1.4x-text/reduced-motion captures passed. **Static analysis clean; production-path release web build passed with exit 0.** Final commands, build result and log hashes are in [the validation manifest](PHASE-E-VALIDATION.json). The full serial suite is supplemented by final Settings/group regressions, motion/focus/keyboard checks, existing visual baseline comparisons and explicit runtime captures.

Captures cover 360x800, 800x360 and 440x900, plus a 320 px test arena, keyboard insets and 1.4x text with reduced motion. Fixtures use local in-memory state and no production accounts or writes.

## Screenshots

| Screen | Phone | Short landscape | Larger frame |
| --- | --- | --- | --- |
| Home artwork | [360x800](screenshots/phase-e/home-360x800.png) | [800x360](screenshots/phase-e/home-800x360.png) | [440x900](screenshots/phase-e/home-440x900.png) |
| My Groups | [360x800](screenshots/phase-e/groups-360x800.png) | [800x360](screenshots/phase-e/groups-800x360.png) | [440x900](screenshots/phase-e/groups-440x900.png) |
| Ball editor | [360x800](screenshots/phase-e/ball-editor-360x800.png) | [800x360](screenshots/phase-e/ball-editor-800x360.png) | [440x900](screenshots/phase-e/ball-editor-440x900.png) |
| Editor with keyboard | [360x800](screenshots/phase-e/ball-editor-keyboard-360x800.png) | [800x360](screenshots/phase-e/ball-editor-keyboard-800x360.png) | [440x900](screenshots/phase-e/ball-editor-keyboard-440x900.png) |
| Settings | [360x800](screenshots/phase-e/settings-360x800.png) | [800x360](screenshots/phase-e/settings-800x360.png) | [440x900](screenshots/phase-e/settings-440x900.png) |
| Power-up Test | [360x800](screenshots/phase-e/powerup-360x800.png) | [800x360](screenshots/phase-e/powerup-800x360.png) | [440x900](screenshots/phase-e/powerup-440x900.png) |

Larger-text/reduced-motion captures: [Groups](screenshots/phase-e/groups-large-text-reduced-360x800.png), [Settings](screenshots/phase-e/settings-large-text-reduced-360x800.png), [Audio tab](screenshots/phase-e/audio-large-text-reduced-360x800.png), [Power-up Test](screenshots/phase-e/powerup-large-text-reduced-360x800.png).

[All 25 image dimensions and hashes](PHASE-E-SCREENSHOTS.json).

## Remaining acceptance

- [ ] User checks the published browser and Android layouts, keyboard, audio and reduced-motion behavior.
- [ ] Actual phone performance comparison, including long Mayhem and effect-heavy matches.
- [ ] Production/deployed-build acceptance after an explicit deploy/release request.

The A-E implementation is complete locally. These manual acceptance items remain open; desktop widget checks and a web build do not establish phone performance. No paid assets, AI image generation, new packages, schema changes, signing/workflow changes or cumulative ZIP.
