# Ball Wars — Free & Open-Source Game UI Redesign

**Codex implementation handoff**  
**Status:** Design/implementation brief; not yet implemented  
**Project:** Ball Wars (Flutter, Android and web)  
**Reference checkpoint:** v1.14.51 RC04 was reported locally test-green with 1,610 tests; inspect the current Git repository to confirm the actual deployed baseline before modifying anything.

## 1. Objective

Replace the *generic Material cards and controls* appearance with a cohesive, polished, sellable **arcade-game visual identity**, inspired by the supplied Ball Wars lobby, match setup, Skill Studio and battle HUD concept mockups. This is a **visual and UX redesign**, not a request to rewrite combat or introduce new game modes/economy features.

**Non-negotiable budget:** Use **only free tools, free/open-source packages, and self-created or permissively licensed artwork**. No paid plugins, paid UI kits, purchases, premium-only exports, commercial subscriptions, or assets with uncertain commercial-use rights. A package being free to download does *not* by itself establish commercial-use permission: verify each dependency and third-party asset license, attribution, redistribution requirements, and compatibility with app distribution before inclusion. Prefer MIT/BSD/Apache-2.0 or similarly permissive dependencies where appropriate. Respect original copyrights; use mockups for high-level inspiration, not copying other games' logos, characters or UI assets.

## 2. Preserve the actual product

Keep existing Ball Wars Flutter architecture, simulation, mechanics, and user configuration intact. Specifically:

- **Modes:** Arsenal, Mayhem, All Out; do not invent ranked matchmaking, online teams or manual skill controls based solely on concept art.
- **Combat:** physics, collision order, projectiles, target selection, damage, RNG, obstacle behavior, elimination, replays, timing and deterministic behavior remain authoritative in current code.
- **Existing UX:** unified Skill Library and six-section editor, Skill Demo, Ball Studio, match setup, Admin settings, rarity presets (Normal, Rare, Epic, Special), square/circular arenas and configurable center obstacles.
- **Art/VFX:** separate equipped/held weapon sprite, Held Attack VFX and Direct Hit Effects; Held Attack VFX renders **above** held weapon artwork. Preserve the v1.14.49–51 fixes and tests.
- **Presentation architecture:** continue Flutter for UI, existing painter/simulation renderer for battle. **Do not migrate to Flame/Forge2D or rewrite the simulation** as part of this UI project. Flame is optional later for isolated visual effects only if a demonstrable benefit justifies it.
- **Existing deployment:** current GitHub Actions workflows and Android signing must remain intact. In particular, Pages deployment should remain `master`-only unless explicitly approved; do not reintroduce tag-triggered Pages deployment rejected by environment rules.

**The generated mockups are illustrative only.** Currency, gems, energy, XP, player levels, ranked teams, real-time controls, quests, shops, monetization and other elements not present in source are **not approved new features**. Translate the *visual language* to the game's existing information architecture and mechanics. Treat the current repository as the source of truth for routes and configuration fields.

## 3. Approved free-first technology stack

| Tool / technique | Intended use | Instruction |
|---|---|---|
| Flutter built-in layout/painting, `CustomPainter`, `ShaderMask`, gradients, `BoxDecoration` | Game-styled cards, chrome, borders, backgrounds | **Primary implementation; no new dependency required** |
| Flutter `Image.centerSlice` / `DecorationImage.centerSlice` | Nine-slice / nine-patch stretchable illustrated frames and buttons | Prefer scalable art without distorted corners; test at multiple sizes |
| `flutter_animate` | Press feedback, pulses, panel transitions, subtle shimmer | Optional; confirm current package version, license and Flutter compatibility |
| `flutter_svg` | Scale-safe icons and decorative vector art | Optional; verify license and supported SVG features |
| `flame` | Isolated sprite or particle presentation components | **Not required initially**; do not replace deterministic game simulation |
| `lottie` (Flutter package) | Optional small celebratory/UI animations | Only with original/permissively licensed animation JSON and verified package license |
| Inkscape | Free vector art authoring | Artwork tool, not a runtime dependency |
| Krita | Free raster art authoring | Artwork tool, not a runtime dependency |
| LibreSprite | Free pixel-art and spritesheet authoring | Artwork tool, not a runtime dependency |

**Explicit exclusion:** No paid Rive plan, paid Rive production exports, paid template libraries, licensed marketplace kits, or other paid-only components. Do not assume every feature of a freemium tool can be commercially exported for free. Use the Flutter animation framework for interaction when possible; minimize dependencies.

## 4. Visual design direction

Build an original, cohesive Ball Wars art system with the following characteristics:

- **Tone:** dynamic, colorful, playful, competitive arcade arena; polished rather than generic enterprise dashboard.
- **Palette:** deep navy/indigo base, electric blue/cyan secondary accents, magenta/violet highlights, warm gold primary calls to action; semantic status colors must remain readable.
- **Surfaces:** beveled or layered panels, controlled gradients, illustrated borders, consistent corner shapes, lightly animated focus/selected states. Use glow sparingly; maintain legibility and GPU budget.
- **Hierarchy:** a clear large primary action, distinct mode selection, visually identifiable rarity, and obvious navigation. Prefer fewer, larger, readable controls over squeezing all concept-art content onto one screen.
- **Typography:** high-contrast, bold section headings, legible body and numeric settings, freely distributable fonts with checked licenses. Avoid tiny stylized text for editable controls.
- **Interaction:** tactile press/selection feedback, concise transitions, clear disabled/error/loading states; preserve keyboard/focus and accessibility semantics.
- **Character art:** reuse and respect user-created Ball Wars sprites; game UI frames should work with genuine transparent PNGs.

### Reusable UI component library

Create a single reusable visual component layer (names are suggestions, adapt to repo structure):

- `GameTheme` / tokens for colors, typography, spacing, glow, rarity treatments and motion.
- `GamePanel` and `GameSectionHeader` for standard panel construction.
- `GameButton` primary/secondary/danger/disabled; press/hover/focus states.
- `GameTab`, `GameSegmentedControl`, `GameToggle`, `GameSlider`, `GameDropdown`, `GameTextField` equivalents, with consistent accessible behavior.
- `GameSkillCard`, `GameRarityFrame`, `GameModeCard`, `GameBallSlot`, `GameIconButton` and appropriate tooltips.
- `GameDialog` / confirmation, errors, validation, empty states and loading states.

Do **not** write per-screen copies of each widget. Keep internal options configurable and preserve existing callbacks, validation and persisted settings.

## 5. Screens and priorities

### Phase A — Foundation and visual prototype

1. Audit actual routes/screens, shared UI widgets, themes, asset loading and layout constraints.
2. Define tokens and reusable controls; build a standalone style gallery/widget tests.
3. Create **original, free-to-distribute** panel/button/rarity/background assets where custom imagery materially improves the result.
4. Validate nine-slice stretching, asset resolution, performance, contrast and touch targets.
5. Demonstrate one small slice of the current Home UI using real app data (no mock currency/progression).

### Phase B — Home and Match Setup

1. Redesign Home/lobby around actual available modes and navigation.
2. Redesign Arsenal/Mayhem/All Out selection and existing match configuration fields.
3. Present rarity presets correctly: **Normal, Rare, Epic, Special**; do not substitute mockup terms such as "Legendary Only".
4. Present existing arena shape, center obstacle, traps and other settings using reusable game widgets.
5. Preserve all existing configuration values, default behaviors and navigation routes.

### Phase C — Skill Library, Skill Editor, Ball Studio

1. Retain unified Skill Library filters (category/source/rarity/status) and six-section editor; **do not introduce independent Built-in/Custom tab hierarchies**.
2. Redesign selection cards, editors, field groups and save/validation controls while keeping all settings discoverable.
3. Keep separate artwork slots for Equipped, Projectile, Impact and Held Attack VFX and current preview functionality.
4. Support dense admin configurations on small phones via scrolling, accordions, contextual navigation or responsive layouts, not minuscule fonts.
5. Bring Ball Studio and Skill Demo into the same design system without changing simulation semantics.

### Phase D — Battle HUD and Replay

1. Use existing battle and replay states; improve overlays/HUD readability without changing simulation timing, deterministic replay data or hit logic.
2. Respect current auto-battle behavior; do not introduce player joystick/ability buttons from illustrative art.
3. Preserve combat diagnostics toggle, victory labels, replay/save/share functionality and existing controls.
4. Keep the arena view unobstructed; adapt HUD to portrait/landscape.

### Phase E — Motion and polish

1. Add measured transitions, panel entry/exit animation, selected-state feedback and optional subtle particle flourishes.
2. Honor reduced-motion settings when available; avoid continuous expensive background effects.
3. Optimize paint bounds, image decoding/caching and frame rendering on entry-level Android devices.
4. Standardize final visual QA, keyboard/focus behavior, accessibility and contrast.

## 6. Artwork rules

- For **Ball Wars gameplay sprite assets**: genuine RGBA transparency; no baked checkerboard or opaque background; sharp pixel art, safe margins, no bleed across atlas/frame boundaries, equal-size sprite cells. Do not distort weapon-held assets or change their orientation requirements.
- For **UI image assets**: use genuine transparency where required, and crisp scalable/vector or properly sliced bitmap assets. Avoid baking user-facing text into button images; labels must remain Flutter-rendered for localization and responsiveness.
- Provide source artwork files where possible, plus exported assets. Track creator/source, license, attribution and asset usage in a manifest.
- Do not ship artwork copied from a referenced commercial game or a web image unless its license permits intended commercial redistribution.
- Store optimized assets in the existing project hierarchy and verify they are declared in `pubspec.yaml`.

## 7. Layout, accessibility, performance

- Verify especially at **360×800 portrait** and **800×360 landscape**, plus at least one larger phone/tablet-like size. Watch SafeArea, soft keyboard, browser resizing and Flutter Web.
- Use adequate touch targets, readable text (including for users who need larger text), text scaling without clipping, semantics labels, and strong contrast.
- Ensure dynamic controls remain usable: sliders, dropdowns, inputs, dialogs, scroll and submit validation. **No visually beautiful but nonfunctional mock controls.**
- Measure rendering cost before and after changes; avoid heavy always-on blurs and excessive composited glow. Keep VFX over weapon as already implemented.
- Visually verify every major state: active, inactive, hover/focus, loading, empty, disabled, error, selected, and text overflow.

## 8. Codex execution and safety rules

1. **Read `HANDOFF.md`, `AGENTS.md` (if present), and existing architecture/tests first.** Inspect the latest repository state before coding; historical ZIPs in `/Ball Wars/Shared Baseline` (including older v1.14.41) are **not** substitutes for a newer production source checkout.
2. **Perform substantial, coherent batches**, not cosmetic one-file mini-patches. But split commits logically within the branch for reviewability.
3. **Do not silently alter gameplay** or data schemas while restyling widgets. No invented features, changed defaults, removed settings or broken deep links.
4. Prefer adapting existing shared UI and painting infrastructure. Add a dependency only for a clear benefit and after license/maintenance check.
5. Add widget/golden tests for new components and regression tests for migrated screens. Maintain existing simulation and replay tests.
6. Run the repository's established test commands; typical local commands include `flutter pub get`, `flutter analyze`, `flutter test -p vm --reporter expanded`. Do not add new GitHub Actions static-analysis steps merely for this project.
7. Report exact testing outcomes; separate **implemented**, **tested**, **visually verified**, and **release-ready**. Do not call a patch release-ready on source inspection alone.
8. Preserve current release/workflow conventions. Do not change `deploy-pages.yml`, `release-apk.yml` or signing unless specifically requested and separately reviewed.
9. For ChatGPT-delivered patches, provide **cumulative changes-only ZIPs**, not full source; include manifest, progress roadmap, validation report and deployment instructions. Codex working directly in Git may instead use commits/PRs according to user's direction.
10. Do not introduce paid features/packages, dependencies with incompatible terms, or asset attribution ambiguity.

## 9. Acceptance criteria

- Current gameplay, settings, saved user data, combat, replay and deployment pipeline behave as before.
- Home and Match Setup are visibly redesigned in an original premium game style using the same reusable components.
- Controls are functional and accessible at 360×800 and 800×360, including scrolling and editing long configurations.
- UI avoids unimplemented progression, economy, team, ranked, or manual-combat features from mockups.
- All assets/dependencies have documented free commercial-use eligibility, with necessary attribution.
- Updated components have widget/golden test coverage; existing tests remain green; performance stays acceptable on target Android devices and web.
- Deliver source changes with a concise change log, screenshots of real running Flutter screens, a dependency/license list and results of analysis/tests.

## 10. Recommended immediate Codex task

> **Implement Phase A and Phase B as the first substantial UI-redesign batch.** Audit the current Ball Wars app, build a cohesive free/open-source reusable game UI theme/components/assets, and restyle the *actual* Home and Match Setup screens. Preserve their existing routes, settings, behaviors and simulation. Do not introduce features depicted only in mockups. Add widget/golden tests, review licenses, validate 360×800 and 800×360, and provide real running screenshots plus a report. Once that foundation is verified, propose the next batch for Skill Studio and Ball Studio.

---

**Reference:** Concept visuals supplied in ChatGPT for the Ball Wars Home/Lobby, Match Setup/Loadout, Skill Studio/Editor and Battle HUD are **style references**, not final requirements or drop-in game assets. If Codex cannot see them in its environment, provide exported images separately; this Markdown remains actionable without them.
