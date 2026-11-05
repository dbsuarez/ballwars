# App frame, match startup and ball labels

Implemented 2026-11-05.

All Flutter routes share the home screen's centered 440px maximum width. Narrower phones use their full width. Dialogs and bottom sheets share that width while retaining content-based height. Their layout uses the local frame dimensions.

Match Settings > Appearance > Ball names places readable names below balls, independently of HP bars above. The preference is remembered per game mode and travels with replay links. Video export's Names option can hide it. Labels remain within the visible canvas.

Bundled artwork now warms after the first home frame. Up to four encoded sprite assets load concurrently, with decoding and registration kept in index order. Ready skills no longer wait for unrelated library downloads. Survival Cut Race skips an unused synchronous finish predictor; simulation rules are unchanged.

## Startup diagnostic

A release Chrome diagnostic with cache disabled and 60ms injected latency per sprite request measured bundled artwork readiness at 3,086ms with serialized requests and 1,237ms with read-ahead. Both fetched 39 resources with no sprite problems. This measures controlled cold artwork loading, not total production startup or audio/network account timing.

Reproduce with the pinned Flutter SDK:

```powershell
flutter build web --release --no-wasm-dry-run --target=tools/performance/startup_profile.dart --output=build/startup-profile
node tools/performance/startup_browser.mjs
```

## Manual acceptance

- [ ] Check phone and desktop route/dialog widths after deployment.
- [ ] Confirm perceived cold match startup on the actual connection.
- [ ] Toggle ball names in each mode; check HP independence, replay and video privacy.

Release validation: 1,739 tests passed / one skipped; static analysis clean. Production release web build passed for v1.14.59. Published device acceptance remains manual.

## Arena priority correction

Portrait matches reserve a width-sized square for the arena. Header, arena, tally and timer form a scrollable page so adding contestants or tally rows cannot consume the arena's height. Landscape layout is unchanged. Eight-ball, short-phone regression and all 29 battle-screen tests pass; analysis is clean.
