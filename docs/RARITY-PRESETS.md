# Player rarity presets

Approved design implemented for new Arsenal, All-Out and Mayhem matches. Threads has no pickups and hides these controls.

| Preset | Normal | Rare | Epic | Special |
| --- | ---: | ---: | ---: | ---: |
| Casual | 35 | 30 | 20 | 15 |
| Balanced (new-match default) | 40 | 30 | 20 | 10 |
| Competitive | 50 | 30 | 15 | 5 |
| Custom | Player weights | Player weights | Player weights | Player weights |

Match Settings > Gameplay contains Power-up Rarity. Each mode remembers its own preset and valid Custom weights under `match-<profile>-rarity-preset` and `match-<profile>-rarity-custom`. Custom initially follows current admin weights until edited; Reset to Balanced saves 40/30/20/10 as that profile's Custom values. Changing presets retains the Custom draft. Bad numbers, values outside 0..100, all-zero weights, or zero weight in every eligible pickup tier prevent starting and show a reason. Decimal weights are supported, matching admin tuning.

The preview uses current weapon toggles, enabled custom skills, their independent tiers, and admin item-tier assignments. It shows percentages among non-trap pickups separately from all spawns including traps. The caption states its empty-field, traps-active assumption. Before traps start, the non-trap column describes all spawns; during a match, occupied pickups temporarily change eligibility. Variants at their carrier's tier share its slot; custom variants at another tier keep their own entry.

The spawn selector and RNG call order are unchanged. Built-in presets select tier shares independently of item count; individual items still share each tier uniformly. Custom permits arbitrary nonnegative relative weights, including zero tiers. Positive weights are normalized over eligible, nonempty tiers.

At match start the player weights are copied into an immutable `MatchConfig.tuning`, preserving all other admin tuning and item tiers. `PowerUpConfig.encode` already writes all four `rarity.*` values and tier assignments for new links. Historical links without weights still decode to the unchanged legacy values 50/45/40/35. Do not change those tuning defaults to Balanced.

Production database checkpoint: the user confirmed `supabase/migrations/022_ball_gender.sql` was applied on 2026-10-28. This is user-confirmed, not independently queried. The sprite importer is a separate pending feature; its planned migration number must avoid colliding with 022.
