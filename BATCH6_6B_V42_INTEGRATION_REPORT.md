# Batch 6B consolidated migration compatibility and packaging pass (v42)

## Source baseline
- Original full source: `ballwars 2026-10-31 1648.zip`
- Cumulative overlay baseline: `ballwars_batch6_cumulative_6B_preservation_verification_v41.zip`

## Corrected compatibility defect
The legacy VFX migration previously reused a same-sprite Visual Event even if that event had non-default opacity, scale, playback mode, or duration. This could change a legacy sprite's visible behavior and cause the preservation guard to reject the entire bulk conversion. The converter and its preflight now share a neutral-effect equivalence predicate, avoiding unsafe reuse and choosing a deterministic suffixed effect ID instead.

## Regression tests added
- Non-neutral same-sprite events: scale, opacity, duration, and loop playback.
- Neutral event reuse and preflight agreement.
- Existing authored Impact with separately migrated Explosion fallback.

## Distribution
- Cumulative overlay contains all v41 changes plus this batch.
- Integrated full-source ZIP applies the cumulative overlay onto the original full-project baseline; no manual merging is required for that variant.

## Verification limitations
ZIP CRC, file-path merge, and static consistency checks are performed. Flutter SDK and Dart executable are not installed in this runtime; compilation, `flutter analyze`, widget tests, and device checks have NOT run. These artifacts are NOT certified production-ready.
