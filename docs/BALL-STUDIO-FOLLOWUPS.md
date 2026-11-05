# Ball Studio follow-ups and test-arena overlays

## Ball Studio

Open Admin Settings > Appearance > Ball Studio.

- **Body:** shared glow enablement, width and color.
- **Face & hands:** expressions, hand style/size, eye size, mouth position/size, pupil-follow strength, optional blink interval and duration.
- **HP bar:** shared Small / Medium / Large appearance.
- **Preview:** actual My Groups/built-in balls, Picture / Face / Both, Single / Phone / Six balls, color, radius, health, held item and forced expression.
- **Presets:** create, apply, replace and delete named appearance drafts on this device. Includes all appearance and glow settings; excludes preview choices and ball stats.

Preview choices are remembered on this device. Apply changes only the draft. Save draft as preset confirms device storage, and reports failures without discarding the draft. Replacing/deleting asks for confirmation. The bottom Save publishes the draft using existing shared settings. Device presets do not synchronize between devices.

The arena and arena-based replay/video renderer use the same face controls. Blinking is optional (off by default), uses the 60Hz simulation step and stable ball IDs, and never consumes simulation random values. Pausing also pauses the blink. Cinematic finishers keep their separate choreography. Existing migration 025's JSON appearance field supports the additions; no new migration is needed.

## Power-up Test

The arena retains its full-width square. Icon-only movement and item controls overlay its sides: A left, B right. Three trap slots sit across its bottom, above the existing finisher previews. All use the 36px finisher-button size. Clear actions remain available. Tooltips and semantics identify the actions; A/B remain non-button identifiers.

Tap a populated item to rearm it; hold to replace. Tap an empty slot to select. Play does not automatically rearm. Random keeps its existing random initial direction followed by normal bounce physics. These changes do not change that behavior. The side rails can scroll independently if needed, without shrinking the arena. Playback/reset/frame/speed/map actions remain below, using compact controls.

## Acceptance

- [ ] Check saved-ball pictures and all preview looks on actual web/Android devices.
- [ ] Save/apply/reopen a device preset; publish it and check shared face/glow settings in a match.
- [ ] Check overlay tap/hold, clearing, finisher previews and dragging on the phone.

Automated verification and local build results are recorded in the current audit roadmap. These changes have not been deployed by this implementation task.

Final local validation: 264 targeted regressions passed; eight final preview/storage checks passed; analysis clean; production release web build passed. Runtime screenshots inspected at 320px and 390px with the actual fonts. No production deployment or APK release was requested for this implementation batch.
