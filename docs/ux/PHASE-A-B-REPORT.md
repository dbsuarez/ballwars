# Phase A + B implementation and validation

Date: 2026-11-06. Baseline: master v1.14.60 (`15c500d`).

## Implemented

Home and Match Setup now use a shared arcade presentation layer: navy/indigo surfaces, cyan/violet accents, warm gold actions, beveled panels and actual interactive controls. Existing palette selections remain supported. Home uses the owner-approved character illustration and retains every real navigation route. Setup retains category search, ball selection, mode-specific settings, rarity weights, loadouts, arena geometry, audio and Start validation.

The foundation uses Flutter built-ins and existing fonts/packages. `GameTheme` styles existing form controls, while the reusable components handle chrome, mode tiles, actions and dialogs. The standalone gallery exercises ordinary controls rather than invented player data. Artwork and notices are tracked in [ASSET-MANIFEST.json](ASSET-MANIFEST.json).

The additional Power-up Test request is included: collapsible remembered rails, no overlay clear buttons, consistent square controls, and finisher previews below the arena. Choosing No item removes a remembered item/trap. Combat, collision order, RNG, replay formats, database schemas, GitHub workflows and Android signing are unchanged.

## Tested

| Check | Result |
|---|---|
| Full regression suite, single worker | 1,758 passed; one existing opt-in test skipped |
| Follow-up palette/legal/player-flow suite after final refinements | 111 passed |
| Final shared-dialog/setup/visual suite | 90 passed |
| Portrait/landscape setup and keyboard focus | Passed at 360?800 and 800?360 |
| Gallery widget and local pixel comparisons | Passed at 360?800, 800?360 and 440?900 |
| Reproducible offline runtime captures | Passed; real bundled fonts and local sample fighters |
| Final analysis / production web build | No issues; release web build passed |

The full suite preceded the final palette, notice and shared-dialog refinements; those refinements were covered by the subsequent focused suites. Counts describe separate runs and must not be added together as distinct tests. Golden comparisons are explicitly enabled locally to avoid treating host-specific font/raster differences as cross-platform proof.

## Visually verified

These are actual Flutter runtime renders with local fixture data. They are not screenshots of a production account or a physical Android device. The landscape Setup capture shows its scrollable lower controls; it retains the shared app width.

| View | Portrait | Landscape |
|---|---|---|
| Home | [360?800](screenshots/home-360x800.png) | [800?360](screenshots/home-800x360.png) |
| Match Setup, selected | [360?800](screenshots/setup-360x800.png) | [800?360](screenshots/setup-800x360.png) |
| Match Setup, disabled | [360?800](screenshots/setup-disabled-360x800.png) | [800?360](screenshots/setup-disabled-800x360.png) |
| Component gallery | [360?800](screenshots/gallery-360x800.png) | [800?360](screenshots/gallery-800x360.png) |

Additional captures: [440?900 Home](screenshots/home-440x900.png), [440?900 Setup](screenshots/setup-440x900.png), [test controls](screenshots/powerup-390x844.png), [collapsed controls](screenshots/powerup-collapsed-390x844.png), [320px test controls](screenshots/powerup-320x740.png).

## Performance and limits

The added illustration is 129,778 encoded bytes; its decoded image is about 2 MiB and uses a bounded cache width. Original concept sheets and the PNG working master are documentation, not runtime assets. There is no new continuously running UI animation or new engine/package dependency. Static chrome and illustration repaint boundaries limit unnecessary work.

A before/after Android GPU/frame-time comparison has not been performed; no phone FPS improvement is claimed. Passing runtime captures and regression tests does not establish hands-on device or production acceptance.

## Remaining manual acceptance

- [ ] Check phone touch accuracy, web keyboard/hover/focus behavior and palette changes on the published build.
- [ ] Confirm remembered mode/settings and real-account groups/replays on web and Android.
- [ ] Open Credits & licenses and inspect font/icon notices on the actual app.
- [ ] Compare phone rendering/frame time and cold start with the preceding release.
- [ ] Verify deployment/APK workflow completion only after an explicit deployment/release request.

Phase A + B are implemented and software-validated locally. They are not a production or physical-device acceptance claim. No deployment, release tag, APK install or cumulative ZIP is performed by this task.

Final bundle verification: the hero image and all three explicit notice files match their source SHA-256 hashes in `build/web`. See [BUILD-ASSET-CHECK.json](BUILD-ASSET-CHECK.json). Runtime screenshots and their dimensions/hashes are recorded in [SCREENSHOT-MANIFEST.json](SCREENSHOT-MANIFEST.json).
