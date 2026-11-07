# Flutter handoff — Battle Garage

## Rendering contract

This visual language is implementable with the existing Flutter engine. Use live
Flutter text and controls over custom art, rather than showing whole screens as
images. There is no runtime dependency on FigCraft.

| Design element | Flutter implementation |
| --- | --- |
| Cut-corner buttons and panels | `ClipPath`/`CustomPainter`, or PNG with `Image.centerSlice` |
| Raised button edge | Separate translated shape or normal/pressed PNG; hitbox stays fixed |
| Rarity cards | PNG skin or stroked path; existing Normal / Rare / Epic / Special meaning |
| Header, tabs, labels and values | `Text`, `TabBar`, `Row`, `Wrap` and layout constraints |
| UI icons | Existing Material icons or direct `Path` drawing from source geometry |
| Pixel-art items | Existing sprite registry; nearest sampling and alpha retained |
| Hero | Existing image with `BoxFit.cover`; no baked controls |
| Arena | Existing `ArenaCanvas` and simulation, including current art and effects |
| Expressions | Existing face painter; concept eyes/mouth/hands are simple geometry |
| Numeric fields | Existing stepper controllers and validation |
| Tint | Existing color picker with a visible swatch |
| Input and feedback | `InkWell`, `Focus`, `Semantics` and bounded animation |

No blur, glass, displacement, noise shader or proprietary animation format is
needed. Font rasterization and anti-aliasing may differ slightly between engines;
pixel identity is not asserted. The Flutter proof demonstrates the custom-control
construction, not a completed screen migration.

## Text-free skins

PNGs are RGBA exports at **1x**. Center slices use source pixels and
`Rect.fromLTWH(left, top, width, height)`:

| Skin | Source size | Center slice |
| --- | --- | --- |
| `skin-primary-normal.png` | 256×64 | `(24, 24, 208, 16)` |
| `skin-primary-pressed.png` | 256×64 | `(24, 24, 208, 16)` |
| `skin-primary-disabled.png` | 256×64 | `(24, 24, 208, 16)` |
| `skin-card-normal.png` | 256×192 | `(24, 24, 208, 144)` |
| `skin-card-rare.png` | 256×192 | `(24, 24, 208, 144)` |
| `skin-card-epic.png` | 256×192 | `(24, 24, 208, 144)` |
| `skin-card-special.png` | 256×192 | `(24, 24, 208, 144)` |

Keep destinations at least 48 px in both dimensions so the 24 px caps do not
overlap. Use path-based art for smaller icon controls. Labels, focus outlines,
icons and hit targets stay separate. A button background can be:

```dart
Image.asset(
  skinAsset,
  fit: BoxFit.fill,
  centerSlice: const Rect.fromLTWH(24, 24, 208, 16),
)
```

Overlay an interactive Material/InkWell layer and live Text. Select normal,
pressed or disabled artwork from real input state. Draw focus separately.
Do not move the hitbox when the pressed image changes its apparent depth.
Give icon-only controls accessible names and ordinary keyboard activation.

## Existing screens and behavior

| Board | Implementation to adapt |
| --- | --- |
| Home | `lib/app.dart`: remembered mode/Mayhem flag and existing navigation |
| Match Setup | `MatchSetupScreen`: groups, lineup, per-mode settings, maps and presets |
| Live Battle | `ArenaBattleScreen` + `ScoreboardOverlay`: actual state and controls |
| Winner | `WinnerModal`: winning move, real standings and save/share callbacks |
| Skill Library | `SkillManagementScreen`: unified filters, import/export and defaults |
| Skill Editor | Current six-section editor, same drafts, fields, Save and errors |
| Power-up Test | Existing rails, loadouts, traps, movement, dragging and finishers |

### Home and match setup

- Keep all five modes. The sample selection is Mayhem, not a changed default.
  Mayhem remains Arsenal-only.
- The primary action opens the selected mode's real setup. Preserve per-mode
  preferences, existing configuration values and start validation.
- Gameplay / Appearance / Audio group existing settings. Content scrolls; the
  representative board is not a request to remove unpictured fields.
- Groups and replays remain together. Keep credits/licenses and platform-specific
  Quit behavior.

### Arena and results

- Portrait arena width equals available app width: 390 px in the main board.
  Never reduce it to fit controls or standings. Scroll surrounding UI instead.
- The landscape board preserves the existing **440 px centered app frame** inside
  an 800×360 viewport. Text in the outside margin is a design annotation.
- These are spectating controls; do not add manual firing or movement controls.
- The winner panel rectangle `(16, 76, 358, 692)` has center `(195, 422)`,
  exactly the center of its 390×844 viewport.
- Preserve the current pinned winner title/actions with scrolling details for
  long results. Landscape overlays span the whole app window.
- Use actual wins/cuts, fewer eliminations and remaining HP/threads. Numbers
  shown in the board are sample data.
- Preserve video visibility/audio choices. Clickable controls remain excluded
  from exports. A future restyle of the export painter must be validated
  separately; no recorded replay data changes are part of this concept.

### Skills and test arena

- Keep a unified library. Category is inline; Source, Status and Rarity remain
  available through Filters. Search preserves active filters.
- Overflow holds import/export and less frequent existing actions. Add creates
  a skill. Global Defaults and Save Library retain their batch-edit purpose.
- The compact editor labels correspond to the existing six sections:
  Identity, Mechanics, Timing & Delivery, Visuals & Sprites, Audio & Callouts,
  Test & Preview. Use full labels in semantics/tooltips and scroll at larger text.
- The active Artwork subtab is illustrated. Keep Grip, Projectile, Effects, Area,
  Shells and current legacy handling discoverable. No parameters are dropped.
- Equipped/projectile previews share the same box and center. Casting, impact
  and held-attack VFX remain separate bindings.
- Rendering scale does not change hitboxes, damage range or projectile origin.
  Tint continues through the skill model and picker.
- Preview / Demo / Live / Finisher stay in a persistent toolbar. Keep unsaved
  previews, Save validation, visible errors and retry behavior.
- Test A is left, B right; three trap slots are at the arena bottom. Keep
  collapsible rails, no clear buttons, tap to rearm one item and hold to choose
  or remove. Play never automatically rearms.
- Random still means a randomized start followed by normal bounce physics.
  Preserve ball dragging and remembered speed/audio.
- Finisher controls reflect actual selected slots and damage eligibility.
  Empty/non-damaging slots are disabled; the sample speed finisher is dimmed.

## Responsive and accessibility rules

- Main mobile boards: 390×844. Additional Home: 360×800. Preserve the existing
  440 px maximum app window on larger displays.
- Use constraints and scrolling rather than scaling the entire UI. At 320 px,
  preserve arena width and let surrounding content scroll.
- Primary controls: 50–58 px. Test Play: 72×72. Main icon targets: 44×44.
  Test rails retain the requested compact 36 px size and require tooltips
  and semantic labels.
- Text stays live. Larger text increases row heights, wraps labels or scrolls
  tabs. Do not squeeze labels into tiny text to maintain this static arrangement.
- `fonts/Inter-Variable.ttf` and `fonts/OFL.txt` provide matching Flutter typography.
  Add them to the runtime bundle only during implementation. The proof loads
  them directly without changing the application's current font configuration.
- Keep reduced motion, visible focus and contrasting enabled/disabled roles.
  Do not restore a global white icon-button foreground override.

## Validation boundary

The FigCraft file exports without missing-font or import warnings. It embeds its
images, and the builder checks all frame/skin dimensions. The explicit Flutter
proof tests alpha, 320/390/800 px viewports, text fit, touch and keyboard activation,
and captures an actual Flutter rendering.

This is a Flutter-compatible design with demonstrated custom controls. Full
production migration, connected prototype flows and real-phone performance still
need implementation/acceptance; those are not claimed by these design artifacts.
