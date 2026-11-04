# Batch 4: Replay and export implementation

Started: 2026-11-04. Master checklist: [whole-app roadmap](WHOLE-APP-AUDIT-ROADMAP.md).

## Implemented

- [x] Fix rejection of an explicit empty built-in pickup mask. `w.0` now means no built-ins; absent selection retains the legacy all/default semantics.
- [x] Regression tests cover custom-only round trips and empty selection while retaining invalid-mask rejection.

## Next coding work

- [ ] Version targeting rules and document historical compatibility limits (A02).
- [ ] Snapshot changing-arena configuration throughout replay and export (A03).
- [ ] Finish empty/custom-only saved/server/export integration checks (A04).
- [ ] Visible failed/unsupported/missing replay-link states and retry (A13).
- [ ] Preserve the current video composition and offer an optional watching composition.
- [ ] Independent saved-video visibility: names, pictures, health, scores/timer/standings, equipped-item indicators, callouts, arena text and watermark. Changing export choices must not change live match preferences or deterministic simulation inputs.
- [ ] Retain BGM/SFX export choices; exclude clickable controls from all saved-video compositions.
- [ ] Admin-configurable DVD watermark, default `cha0s' Balls`, with export visibility choice.
- [ ] Portable `.bw` import/export UI.
- [ ] Integration tests and builds; leave requested manual playback checks to the user.

This batch has started, not completed. No new export visibility control is claimed implemented yet. Existing rendering, codec pipeline and audio export remain in place.
