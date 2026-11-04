# Ball Wars v1.14.51 RC03 - Combat Diagnostics and Obstacle Demo

## Scope
Cumulative **changes-only overlay** based on v1.14.51 RC02; incorporates the RC02 repair and earlier RC50 cumulative files. Apply to the tested **v1.14.50 / v1.14.51 project**, not the historical v1.14.41 full baseline.

## New implementation
- Match arena includes a **Show combat diagnostics** button (eye icon); defaults off and is local to the screen. Debug painting runs in a read-only overlay with IgnorePointer. It draws physical ball collision radii, selected aiming lines, blocked-vs-clear center-obstacle targeting lines, obstacle shape, projectile collision circles, and current velocity direction. It does not mutate RNG, hitboxes or target state.
- Skill Demo includes a separate Combat diagnostics switch with the same overlay; its older Inspect effects switch remains available.
- With center obstacle Circle or Square selected, Skill Demo now shows **Obstacle shot scenario**. Head-on preserves the legacy scene with the obstacle between opponents. Clear lane places both on the same side, keeping the real obstacle physics enabled. A path label indicates whether the current line crosses the obstacle. Changes reset the isolated scene through the existing preview-mutation mechanism.
- New tests check both obstacle variants, setup/reset and live-match mechanics, plus read-only overlay painting.

## Validation and outstanding work
- User confirmed 1,607 passing Flutter tests for **RC02**, not RC03.
- RC03 has source-level integration / archive checks only. Flutter and Dart SDK tools were not present here, so RC03 compilation, analyzer and runtime tests **remain unverified**.
- Diagnostics show projectile *current direction*, not a future trajectory prediction; existing damage and obstacle geometry are preserved. Skill Demo uses the existing real-match activation, homing and wall collision systems; it is not a separate physics simulator.
- Manual inspection recommended for circular/square obstacles, both facing directions, compact 360x800 screens, and the visibility of the new diagnostics toggle during battle.

## Roadmap
| Workstream | Implemented | Test authored | User-verified RC03 | Release-ready |
| --- | --- | --- | --- | --- |
| Sticky / obstacle-aware targeting + dead target lifecycle | Yes (RC02) | Yes | No (RC02 was green) | No |
| Homing targeting preservation | Yes (RC02) | Yes | No (RC02 was green) | No |
| GitHub Pages master-only workflow | Yes (RC01) | N/A | No | No |
| Live arena combat diagnostics | Yes | Yes (read-only painter) | No | No |
| Skill Demo obstacle blocked/clear scenarios | Yes | Yes (circle/square) | No | No |
| Skill Demo diagnostics / path status | Yes | Controller tests | No | No |

## Apply / test
1. Unzip archive into the current Ball Wars project root, keeping directory structure. It contains only accumulated changed files, not the complete project.
2. `flutter analyze`
3. `flutter test -p vm --reporter expanded`
4. Play with 3+ balls and circle/square obstacles; toggle the eye icon; inspect yellow ball collision bounds, cyan clear targeting, orange blocked lines, and projectile travel vectors.
5. In Skill Demo select circle/square center obstacle, choose Head-on then Clear lane, activate an aimed projectile, and toggle Combat diagnostics. Confirm the path labels and real projectile contact behavior.
6. Do not deploy until RC03 tests and manual visualization pass.
