# Six-ball profiling, 2026-10-29

Actual release-mode Windows Chrome, AMD Radeon graphics, 16 reported logical cores. Six balls, 720 simulation steps, 120 offscreen 360 x 360 raster frames; peak 15 projectiles, 7 sources and 475 particles.

| Measurement | Mean | P95 |
| --- | --- | --- |
| Simulation | 0.558 ms | 1.300 ms |
| Offscreen raster/readback | 21.253 ms | 37.900 ms |

Registered decoded frame estimate: 4,796,416 bytes (4.57 MiB). This excludes heap, decoder staging, fonts and GPU overhead. Raster timings include Picture.toImage snapshot/readback; these are not onscreen frame timings or proof of 60 FPS. No Android device was connected, so Android performance acceptance remains unchecked.

[Raw browser measurements](performance/2026-10-29-six-ball-chrome.json).

Reproduce the release browser harness:

```powershell
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --output build/web-profile --target tools/performance/six_ball_profile.dart
python -m http.server 8329 --bind 127.0.0.1 --directory build/web-profile
```

Open localhost:8329 in Chrome and capture the BALLWARS_PROFILE console record. The native opt-in regression harness is `flutter test --dart-define=PROFILE_SIX_BALL=true test/performance/six_ball_artwork_profile_test.dart`; it is skipped in normal suites and is not a substitute for phone profiling.
