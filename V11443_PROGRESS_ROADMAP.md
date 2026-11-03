# v1.14.43 Match Settings / Arena Configuration audit and completion

Source: consolidated v1.14.41 baseline, with v1.14.42 hand artwork cumulative repair overlaid for inspection.

## Already implemented in baseline (not rewritten)
- Per-mode arena shape, center obstacle, size and rotation settings use `match-<mode>-*` preference keys with legacy fallback.
- Shrinking Arena appears in the arena configuration group, not Gameplay.
- Pre-match master, arena and skill trap switches inherit administrator values and preserve disabled selections.
- Timed arena-change warnings use `secondsUntilNext` with match duration, and suppress next change at or after match end. Endless mode retains countdown.
- Match Settings supports grouped list and individual cards.

## New in this patch
- 'Use administrator trap defaults' action resets all three per-mode trap overrides without modifying global admin settings.
- Persisted `inherit` sentinel restores nullable inheritance on restart; existing 0/1 values remain supported.
- Added explicit rotation warning boundary regression for timed/endless matches.

## Verification / release gate
- ZIP CRC and SHA256 validated. Flutter SDK is not installed here: no Flutter analyze or tests executed.
- Existing 1,555-pass v1.14.42 run predates this patch.
- Run `flutter analyze`, `flutter test`, and manually check per-mode trap override/reset and mode switching on phone.
- This patch is changes-only and should be applied on top of the consolidated baseline plus v1.14.42 repair.

## Status
Existing roadmap functionality: source-audited, not newly tested.
New reset action: implemented, awaiting Flutter verification.
Release readiness: pending user tests and phone acceptance.
