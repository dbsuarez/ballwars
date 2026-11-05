# Flame rendering feasibility

2026-11-05. Isolated branch `experiment/flame-renderer`, worktree
`.worktrees/flame-renderer`. Production remains on the existing renderer.

## Recommendation: keep the current production renderer

The prototype is compatible with the tested rendering and replay/export paths,
but this study does not justify a production migration. Phone results are
workload-dependent: component rendering regresses the effects-heavy scene and
improves the changing-arena scene. Headless-browser differences are small and
mixed. The wrapper alone captures much of the changing-scene improvement,
suggesting widget scheduling/repaint work is worth investigating independently
of an engine change. No domain rendering subsystem was removed.

Keep `experiment/flame-renderer` for future experiments. Proceed with the named
arena editor/catalog on the current renderer when that feature is authorized.
Before revisiting migration, seek a repeatable benefit across representative
workloads and a concrete reduction in custom rendering responsibilities.

[Release measurements and raw evidence](flame-study-results/MEASUREMENTS.md)

## Scope and decision rule

This study tests an incremental rendering integration, not new physics or a game
rewrite. Migration needs correct replay/export behavior, a repeatable runtime
benefit, and less custom infrastructure to maintain. Compatibility alone is not
sufficient. The result does not establish that every possible Flame architecture
would have the same performance.

## Prototype

The existing simulation, seeded randomness, fixed-step clock, targeting and
combat are unchanged. One external driver advances simulation at 1/60 second;
Flame's update never ticks it. The same state provider feeds four paths:

| Path | What actually changes |
| --- | --- |
| Current painter | Original CustomPainter orchestration |
| Flame wrapper | Full ArenaPainter inside GameWidget; integration baseline only |
| Flame components | Separate floor, combat, particles, ball and overlay components; persistent per-ball views preserve simulation depth order |
| Flame components + sprites | Same component graph, with cached Flame Sprite rendering for the central item/projectile/effect image helpers |

The component prototype reuses domain-specific drawing primitives. Projectiles
still use the existing batch/orchestration and simulation-selected animation
frames; they have not all become independent SpriteAnimationComponents. The
sprite path is genuine Flame Sprite rendering, not the full-painter wrapper.
The registry still owns image lifetime, atlas revisions, slicing, anchors and
step-driven frame selection.

Flame 1.35.1 resolves with Flutter 3.38.5 / Dart 3.10.4. The experiment adds two
resolved dependencies (Flame and ordered_set). The production pubspec is unchanged.

## Correctness

- Four fixture configurations cover six contestants, dual weapons, projectiles,
  animated slash/fire/explosion artwork, circle/square boundaries, center walls,
  shrinking and a theme/shape transition. The effects and six-ball snapshot
  currently share a visual setup; this is three unique pixel scenes.
- Every Flame path matches current-painter RGBA pixels exactly, 540x540.
- Separate original-production captures verify the extraction itself did not
  change the three distinct reference scenes.
- Render/update calls preserve the tested simulation fingerprint.
- Existing arena painting and video-export checks still pass. The offscreen
  experiment renders without GameWidget or advancing gameplay.
- The isolated offscreen bootstrap currently uses Flame's internal `load` entry
  in the test, with an explicit analyzer exception. Depending on that internal
  API in a production exporter would require an adapter and compatibility checks.

The benchmark fixture explicitly enables both timed Mayhem and respawning. A
regression check keeps all six balls active through the transition. Initial runs
without respawning, and runs served from a stale service worker, were discarded.
Pilot timings with unequal repaint boundaries were also discarded. The final
harness gives each path one equivalent outer RepaintBoundary and disables
GameWidget's extra automatic boundary. The final browser runner uses a fresh dedicated profile and bypasses service
workers; it does not interact with the user's browser profile.

## Measurements

Both final runners completed 16 valid cases each. On the connected Infinix X695
(Android 11, 1080x2460, density 480), mean run-level UI P95 for components was
16.46 ms versus 11.42 ms for the painter in the effects scene, and 13.36 ms versus
18.05 ms in the changing scene. These are two-run descriptive means, not pooled
percentiles or statistically significant estimates. Individual runs vary
substantially; the evidence supports a mixed result, not a universal engine win.
Phone PSS observations ranged from 143.0 to 182.1 MiB. No renderer-specific memory
advantage is established. See the raw run-level values before interpreting means.

Final benchmark results are recorded in `flame-study-results/`. Two 15-second
measurements per renderer and scene run in forward then reverse order, each after
a two-simulation-second warmup. Cases must complete at least 900 measured steps
and retain six visible balls. A wall-clock guard marks incomplete cases rather
than waiting forever.

The native study package is `com.ballwars.ballwars.flamestudy`, labelled
**Ball Wars Flame Study**, separate from the production app. It uses an
app-scoped wake lock only while open. The harness verifies its package ID before
installing, records only this app's logs/memory, then force-stops it when done.
It does not clear or change production app data.

Headless Chrome results describe the controlled headless environment, not
perceived smoothness in a normal visible browser. Its pacing is not synchronized
to a physical 60 Hz display. Flutter FrameTiming and ticker intervals are
reported separately. The 16.667 ms counter is a reference threshold, not a
refresh-rate-aware assertion of dropped frames.

CPU command-recording numbers come from a JIT test, exclude GPU rasterization,
and are diagnostic only. Asset loading is shared by the paths within one run;
its single preload duration does not compare engine-specific cold launches.
Memory sampling across renderer switches includes warm caches and GC effects,
so it cannot establish a per-engine memory advantage or prove absence of leaks.
The standalone study APK is not size-comparable to the full production app.

## Maintenance assessment

Flame supplies a component tree, game widget/loop and Sprite drawing. In this
prototype it removes no domain subsystem. Custom skill semantics, artwork
bindings and revisions, mirroring, grip/emitter placement, layering, callouts,
face expressions, geometry, particle data and replay timing still need their
existing code. The new component graph, sprite cache and integration boundaries
add code. Both rendering paths are retained for rollback and export parity.

Replacing the registry's fixed-step playback with wall-clock animation would
risk replay seeking and export consistency. A future deeper conversion would
need a simulation-clock adapter plus the current custom-asset metadata rules.
No physics, collision or targeting migration is proposed.

## Reproduction

Use the pinned Flutter 3.38.5 SDK (the global PATH may point to another version).
From the worktree:

```powershell
$Flutter = 'C:/Users/cha0s/fvm/versions/3.38.5/bin/flutter.bat'
& $Flutter pub get
& $Flutter run --release -t lib/flame_study_main.dart
& $Flutter test test/experiments/flame_renderer_test.dart
```

Manual mode offers the four renderers, scenario selection, same-seed reset,
pause, 15-second measurement and copyable results. For the automatic suite build
with `--dart-define=STUDY_AUTO=true` and use
`tools/flame_study/browser_benchmark.mjs` or `phone_benchmark.mjs`.
Results stay in local files/logs; no automatic result upload exists.

## References

- [Flame GameWidget](https://docs.flame-engine.org/latest/flame/game_widget.html)
- [Flame component/render loop](https://docs.flame-engine.org/latest/flame/game.html)
- [Flame rendering on Flutter Canvas](https://docs.flame-engine.org/latest/flame/rendering/rendering.html)
- [Resolved Flame 1.35.1](https://pub.dev/packages/flame/versions/1.35.1)

## Verification status

- [x] Separate experimental worktree/branch, without production renderer changes.
- [x] Six-ball fixture, actual Flame components and Flame Sprite path.
- [x] Exact pixel comparisons including unmodified production references.
- [x] Simulation fingerprint remains unchanged by rendering and Flame updates.
- [x] 22 targeted rendering/fixture/export checks passed; source analysis clean.
- [x] Release web and separate-package Android builds passed.
- [x] 16 valid phone and 16 valid headless-browser cases; raw evidence retained.
- [x] App memory observations, adapter-cost review and no-go recommendation.
- [ ] Human review in a normal visible browser and subjective phone smoothness.
- [ ] Separate renderer-specific cold launches, longer thermal/GC soak and other target phones before any migration reconsideration.

The study app was force-stopped after capture. It remains installed separately
as Ball Wars Flame Study; production app data was not changed. No production
push, release tag or engine switch is part of this study.
