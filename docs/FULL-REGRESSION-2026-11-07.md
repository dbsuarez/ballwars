# Full regression closure - 2026-11-07

**1,787 passed, one existing opt-in performance profile skipped, zero failures.**
All 248 ordinary `*_test.dart` files ran in 16 sequential batches with Flutter
3.38.5. Each batch used concurrency 1 and a fresh Flutter process, avoiding the
Windows memory exhaustion from the earlier monolithic run.

The skipped test is `six-ball simulation and raster profile`; it is an existing
opt-in performance capture, not a failing functional test. This run covers all
normal tests, including the UI skins, portal sizing, death freeze/replay revision
11, sprite import, settings, replay export, and database SQL contract checks.

[Executed inventory, source hashes and results](FULL-REGRESSION-2026-11-07.json)
were reconstructed from the runner's actual suite events and checked against the
complete file inventory. The replay-budget contract test now reads canonical
migration 026; that change was present before its batch executed. Raw machine
logs remain in `build/regression-batches/` and are not committed.

Reproduce on Windows:

```powershell
python tools/run_regression_batches.py --flutter C:/Users/cha0s/fvm/versions/3.38.5/bin/flutter.bat
```

The helper records every batch exit status and test result. It checks executed
file coverage and detects source changes after a test executes. A failed batch,
empty inventory, mismatched coverage or changed source cannot report success.
This is sequential process isolation, not parallel agent work.

Final static analysis: **no issues found**. Python helper syntax and the schema
verifier's negative checks also pass: it rejects a missing blood-color column,
a disabled limit trigger, and a changed replay-budget function.

## Supabase closure

[CLI setup and migration evidence](SUPABASE-CLI-SETUP.md) are ready for Git.
All 29 local/remote versions match, and the no-write push preview says the remote
database is up to date. Migration 013 was the only missing schema change and was
applied with explicit user approval. Existing application data was preserved.

## Still manual

Physical phone acceptance, subjective pacing/performance, live browser gestures,
file-picker behavior and published-build acceptance remain separate from these
automated results. GitHub workflows are not monitored automatically. No APK tag
or phone installation is part of this maintenance follow-up.


## Concurrent work boundary

After the completed full run, new uncommitted Power-up Test layout/code and test
edits appeared. They are not part of this maintenance commit. A separate rerun
of that screen produced **23 passed and one failed**: `arena and controls center
together with a large reachable Play button` measured 217 px against a <150 px
reachability limit. Those edits were preserved for their active author. The
1,787-pass result applies to the recorded full-run snapshot, not a claim that
this newer dirty layout has passed. This separate regression needs resolution
in the concurrent layout work.


### Reachability follow-up resolved

After reviewing local commit `97490e6`, the added loadout row was moved below the
playback buttons. The 72 px Play button is closer to the arena without changing
arena width. All 23 Power-up Test checks now pass, including the <150 px
reachability check; static analysis is clean. Runtime previews:
[390 x 844](ux/screenshots/powerup-loadout-layout-390x844.png) and
[360 x 800](ux/screenshots/powerup-loadout-layout-360x800.png).
