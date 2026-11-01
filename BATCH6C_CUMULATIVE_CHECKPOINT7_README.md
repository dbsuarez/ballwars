# Ball Wars Batch 6C cumulative checkpoint 7

This source PATCH supersedes checkpoints 1-6. Apply over the same full-project baseline used for Batch 6C. Not a standalone Flutter project.

## New in checkpoint 7
- Five additional opt-in behavior starting points: reactive self effect, elimination pulse, periodic aura, directional beam, and all-opponent effect.
- Reactive and timed starting points set explicit cooldown or timer interval defaults where relevant.
- Existing cooldown and timer settings are preserved by other presets.
- Editor updates the timing fields when a preset explicitly supplies them; changes remain drafts until Save.
- Six additional pure-domain regression tests.

## Scope and limitations
- Presets only configure existing trigger/targeting/delivery settings; they do not implement new runtime mechanics.
- Presets do not change skill identity, damage, effects, artwork or rarity.
- Flutter and Dart SDK unavailable here: tests and analyzer were not run. ZIP integrity verified.
