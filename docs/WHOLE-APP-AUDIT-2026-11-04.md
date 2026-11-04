# Ball Wars whole-app audit

Date: 2026-11-04 (Asia/Taipei)
Baseline: `91ab400`, package `1.14.51+11451`, local `master`
Reference: `HANDOFF v1.14.51_RC04.md`

## Remediation update: Batches 1 and 2

BW-A01 and BW-A05 through BW-A09 are implemented locally and covered by the recovery tests. BW-A10 through BW-A12 now have local fixes and regression coverage for stable finisher identity, restore retry and unsaved-draft navigation. See the [Batch 1 report](BATCH1-PERSISTENCE-RECOVERY-2026-11-04.md), [Batch 2 report](BATCH2-SKILL-EDITOR-IDENTITY-2026-11-04.md) and [current roadmap](WHOLE-APP-AUDIT-ROADMAP.md). The findings and observation probes below describe the original `91ab400` audit baseline; they remain historical evidence, not current failing acceptance tests. A02-A04 and A13 now have local Batch 4 fixes and regression coverage; remaining migration/device acceptance and historical provenance limits are recorded in the Batch 4 report. Original findings below remain baseline evidence.

## Outcome

The existing automated baseline is green, but it does not cover several important persistence, recovery and replay contracts. This audit identifies **13 actionable findings: 3 high-priority and 10 medium-priority**. Ten isolated probes reproduce underlying defects or ambiguous identities. Three additional findings come from direct UI/control-flow inspection. No production behavior was changed during the audit.

This is a whole-app, risk-based engineering audit across the feature areas below, not a line-by-line proof of all 64,837 source lines or a claim of real-device acceptance.

### Independently executed verification

| Check | Result | Evidence |
| --- | --- | --- |
| Existing Flutter suite | **1,610 passed, 1 skipped**, no failures | `build/whole-app-audit-tests.log` |
| Source/test/tool analysis | **No issues found** | `build/whole-app-audit-source-analysis.log` |
| Release web build, `/ballwars/`, full HEAD artwork revision | **Passed** | `build/whole-app-audit-web.log` |
| Browser download JavaScript harness | **1 passed** | `build/whole-app-audit-js.log` |
| Additional isolated audit probes | **10 observations reproduced** | `build/whole-app-audit-probes.log` |
| Actual browser visual/playback/audio acceptance | **Not performed** | Flutter widget tests and JS mocks are not a real browser session |
| Android install, audio latency, codec playback, performance | **Not performed** | No device acceptance claimed |
| Live cross-device synchronization, database migration application | **Not queried** | Repository logic/migrations reviewed locally only |
| GitHub Actions, production deployment, phone-installed version | **Not verified** | No deployment monitoring, push, tag or release performed |

The probe assertions describe current undesirable behavior. Their passing result is **evidence of defects, not acceptance of that behavior**. They are separate from the existing 1,610-test suite and are included in the audit evidence archive.

The handoff command `flutter test -p vm --reporter expanded` is rejected by Flutter 3.38.5 (`Could not find an option or flag "-p"`). The successful command was `flutter test --no-pub --reporter expanded`.

An initial root-wide analysis found 52 informational diagnostics exclusively in generated Flutter test listeners under the task's D-drive TEMP directory (`build/tool-temp`). Explicit analysis of `lib`, `test`, `integration_test` and `tool` is clean. Do not confuse generated listener diagnostics with app-source defects; avoid putting analyzer-visible temporary Dart files under the checkout for normal development, or explicitly exclude generated build output in a future tooling change.

## Scope and coverage

Inventory: **162 Dart files in lib, 220 Dart files in test**. Existing unrelated local deletions of historical archives/RC reports, and the untracked handoff, were preserved.

| Area | Review performed | Evidence and limits |
| --- | --- | --- |
| Startup, navigation, auth | Startup wiring; separate admin/device clients; remembered-session policy; deep-link failures | Auth/session and navigation suites pass; browser hard-refresh/session broadcasts still need actual acceptance |
| Groups and synchronization | Active-account routing, adoption, cache keys, network fallback, image upload/cleanup and group-limit migrations | Five targeted group/cache observations below; no production account mutation |
| Match Setup and presets | Per-mode keys including separate Mayhem profile; pickup selection; arena/rotation controls; user/admin map picker | Setup/profile/rarity/rotation tests pass; no persistent authored-arena catalog found |
| Combat and all modes | Shared targeting, eligibility, replay-rule gates, geometry, center walls, trap lifecycle, respawn/tallies and native skill adapters | Full relevant suite passes; historical targeting compatibility gap reproduced |
| Skill Management | Unified library, six editor sections, visual subtabs, save chain, count linking, native controls, custom identities, restore and exit paths | Round-trip/authoring tests pass; restore error handling, unsaved exit and finisher identity gaps remain |
| Sprites and effects | Upload limits, frame validation, revision archival, replacement conflict checks, loader/cache caps, dependency readiness and backup | Existing sprite/slot/renderer/golden suites and JS backup harness pass; actual GPU memory and imported artwork appearance not certified |
| Presentation and mobile UX | Canvas/HP/hand configuration, callout/VFX layering paths, fixed editor testing tools and existing phone-size tests | Widget tests pass, including phone-sized cases; no new human visual review of the complete app |
| Audio | Three-channel controls, preferences, audio initialization/prewarming and export mixer/backend wiring | Existing audio tests pass; timing, hardware mixing and browser gesture restrictions need hands-on checks |
| Replays and video | Snapshot fields, encode/decode contract, saved-store writes, sharing/opening, export reconstruction and watermark | Four direct replay/persistence observations plus historical compatibility and identity issues below; export redesign remains last |
| Supabase and release delivery | Local SQL/RLS/quotas, immutable sprite revisions, settings save policy, workflow triggers/signing/version sources | Master-only Pages and tag-only APK workflows retained; live policies/secrets/signatures/CI were not inspected |

## Findings

Priority definitions: **P1** = data loss or incorrect reproduction of a match; **P2** = significant recovery, identity, privacy-boundary or editor reliability gap. Findings describe this checkout, not proof that every production user has encountered them.

### BW-A01 ? P1 ? Replay saves can report success without persisting anything

**Evidence:** `lib/core/offline/device_prefs.dart:25-32`; `lib/features/replay_export/data/saved_replay_store.dart:94-120`; `lib/features/arena_simulation/presentation/arena_battle_screen.dart:695-709`.

`DevicePrefs.write` swallows storage errors. Saved replays use it for actual user data, then the arena displays ?Replay saved on this device.? A failing-store probe completed `SavedReplayStore.add` successfully, but a subsequent load returned no replay. Rename, removal and share-link attachment use the same write primitive.

**Fix:** Separate best-effort cosmetic preferences from durable user-data writes. Return/throw a persistence result, commit replay records reliably, and show success only after confirmation. Keep the user's replay available for retry/export when a write fails.

**Acceptance:** Full/quota-blocked storage produces a visible error; retry succeeds; saved replay survives reload; failures do not silently erase or replace an older saved record.

### BW-A02 ? P1 ? New targeting behavior is applied to older replay revisions

**Evidence:** `lib/features/arena_simulation/application/power_up_system.dart:2892-2918`, `4581-4591`; `lib/features/arena_simulation/domain/combat_targeting.dart:10-69`. Historical comparison: `b85b516` used first-in-contestant-order nearest targeting; current `_nearestTarget` unconditionally applies ID tie-breaking, hysteresis and visibility preference.

A runtime probe with equal-distance targets showed the new ID-based choice even for simulation revisions **1, 4 and 6**. The older implementation would fire in the opposite direction. A seed and skill snapshot therefore do not by themselves preserve historical match behavior.

**Fix:** Establish an explicit simulation-version compatibility policy. Introduce a new rules revision for changed mechanics, keep documented legacy policies where feasible, and add historical targeting/outcome fixtures. Some already-published links share revision numbers across changed algorithms, so do not promise perfect retroactive recovery without identifying their originating version.

**Acceptance:** Old-rule fixtures retain their recorded decisions; new matches opt into the new policy; homing/reflection and defeated-target eligibility remain correct. Preserve the current crash/lifecycle fixes deliberately rather than blindly restoring an old implementation.

### BW-A03 ? P1 ? Arena rotation is lost when saving/sharing/exporting a match

**Evidence:** Live controller wiring at `arena_battle_screen.dart:218`; snapshot construction at `:643-679`; `ReplayLink` has shape/obstacle fields but no `ArenaRotation`; `ReplayVideoExporter.newMatch` at `replay_video_exporter.dart:129` has no rotation input.

A six-ball probe advanced a live rotating arena and its replay reconstruction to 30 seconds: **live = square; replay = circle**. Theme rotation also changes automatic hazards, so this can alter damage and results, not merely scenery. The in-place Replay action retains the live config; portable replay and video reconstruction are the affected paths.

**Fix:** Snapshot both rotation toggles and interval, decode/version them, pass them through opening/export, and test post-transition state/outcome parity. Keep this in the final replay batch as requested.

### BW-A04 ? P2 ? A legitimate empty built-in pickup selection produces an unreadable replay

**Evidence:** Match Setup stores and passes an empty selected set (`match_setup_screen.dart:697`, `:774`). Replay encoding emits `w.0`; `replay_link.dart:310-325` rejects `mask <= 0`.

The encoder/decoder probe confirms `ReplayLink.fromUri(link.toUri(...)) == null` for an Arsenal match with `powerUps: {}`. This also matters for custom-only loadouts.

**Fix:** Give ?none? an explicit supported encoding, distinct from null/all, and retain backward compatibility. Test no pickups, custom-only pickups, and all pickups through saved/local/server/export paths.

### BW-A05 ? P2 ? One failed group-adoption request poisons later retries

**Evidence:** `custom_group_repository.dart:570-595`.

`_adoption ??= _adoptDeviceGroups()` caches a failed future forever for the repository instance. A transient failure on the first request means a second request immediately fails without trying again. The isolated probe observed **one adoption call across two failed user requests**.

**Fix:** Clear the cached future on failure, coalesce concurrent successful requests, and key adoption state to the active source/target identities. Also cover logging into a different admin account during the same app session.

### BW-A06 ? P2 ? Browser-style network errors bypass cached groups

**Evidence:** `custom_group_repository.dart:252-270`.

Fallback handles `TimeoutException` and `SocketException` only. An HTTP `ClientException` representing ?Failed to fetch? propagates even when the requested groups are already cached. The probe loaded/cached a group online, then reproduced this failure with a browser-style HTTP connectivity exception.

**Fix:** Classify transport errors explicitly, including browser/client failures. Continue surfacing authorization, malformed data and server-policy errors; do not replace this with a catch-all that disguises those failures as offline success.

### BW-A07 ? P2 ? Cache write failure discards successfully fetched group data

**Evidence:** `custom_group_repository.dart:255-258`.

The cache write is part of the successful network-read path and is not isolated. A mock HTTP response succeeded, but a local ?disk full? cache exception caused `myGroups()` to fail instead of returning its fresh rows.

**Fix:** Return validated server results even if the replaceable cache cannot be updated. Distinguish a cache warning from a failed server read. This is separate from BW-A01: replay documents are durable user data, while fetched groups have a server source of truth.

### BW-A08 ? P2 ? The all-groups cache is not account-scoped

**Evidence:** `custom_group_repository.dart:166-183`, cache key `groups:all`.

A probe populated the all-groups cache with a private group using an admin client, then used a different anonymous client with a socket failure. The repository returned the private cached group. Mine/saved caches are correctly scoped; this one is not.

**Boundary:** This demonstrates a local repository/cache isolation problem on a shared device. It does **not** demonstrate a server RLS bypass or remote anonymous access to the database. Normal anonymous UI access to the admin list was not demonstrated.

**Fix:** Scope sensitive caches by verified identity/access level; do not reuse admin-wide results for another account; review any mounted admin lists during logout/account switching.

### BW-A09 ? P2 ? Stale administrator saves overwrite unrelated newer changes

**Evidence:** `app_settings_repository.dart:157-244`.

Settings saves send a whole loaded snapshot and filter only by `id = 1`; `updated_at` is written, not used as a conflict condition. A two-reader probe saved a new headline from one instance, then changed only the theme from the stale second instance. The headline reverted to its old value.

**Fix:** Use optimistic concurrency or a server-side field-scoped update contract. Surface conflicts with reload/retry, retaining the draft. Sprite replacements already perform an expected-revision check; shared settings need an equivalent deliberate policy.

### BW-A10 ? P2 ? Finishers resolve skill identity by a nonunique display name

**Evidence:** `match_simulation_controller.dart:157-158`, `:1221`, `:1271`; `arena_battle_screen.dart:1331-1363`; `skill_library.dart:2136-2154`.

Distinct custom skill IDs may legally share a name. A probe created two such skills with different tint. The live finisher lookup uses `.where((s) => s.name == winningMove).firstOrNull`, so a win by the second skill can resolve the first skill's artwork/settings. The probe confirms the ambiguous identities; the wrong lookup is confirmed in the live call site, not through a full cinematic visual test.

**Fix:** Record the winning skill's stable ID and activation-time presentation snapshot separately from its label. Keep explicit identities for collision, thread-cut and environmental/arena-trap wins.

### BW-A11 ? P2 ? Library-level ?Restore original settings? has no save-error feedback

**Evidence:** `skill_management_screen.dart:260-296`, `:615`.

The menu starts `_restoreBuiltIn` without awaiting/handling its future. That function awaits `widget.onSave` without a catch or visible failure state. A failed network/admin save bypasses the editor's otherwise good save/retry feedback path. **Inspection finding; no failing live backend action was attempted.**

**Fix:** Route restore through the same guarded save/error presentation as editing. Keep the prior library unchanged on failure and allow retry without leaving an uncaught asynchronous exception.

### BW-A12 ? P2 ? Closing a skill editor discards unsaved changes without warning

**Evidence:** `skill_management_screen.dart:3538-3542`; no `PopScope`/dirty-draft exit guard is present.

The dedicated editor's close button directly pops the route. Main/subtab switching retains drafts, but closing or system-back can lose a long editing session. **Inspection finding.**

**Fix:** Track a canonical baseline/draft and offer Save / Discard / Keep editing on a dirty exit, covering close, keyboard/back and Android navigation. Do not prompt for a clean or just-saved draft.

### BW-A13 ? P2 ? Failed replay links silently return to Home

**Evidence:** `lib/app.dart:415-459`.

Missing server codes, resolve failures, unavailable packs/groups and invalid decoded links return without explaining the failure. An invalid replay can therefore look like the app ignored the user's tap. **Inspection finding.**

**Fix:** Present distinct unavailable/not found/unsupported messages with retry where useful. Retain the requested replay identity until resolution succeeds or the user cancels.

## Roadmap reconciliation

The historical roadmaps are not a current completion ledger. In particular, the Skill Management document marks complete replay/video UX while the arena roadmap still lists that redesign as pending.

| Original request | Current evidence | Audit status |
| --- | --- | --- |
| Unified Skill Library, grouped editor, visual subtabs, numeric steppers | Current editor and authoring tests | Implemented; reliability issues A09-A12 remain |
| Separate profiles for modes including Mayhem | Profile keys and setup tests | Implemented; actual two-device persistence acceptance not claimed |
| Ball Studio, expressions, HP sizes and outline | Renderer/settings and tests | Implemented; device visual acceptance pending |
| Square outer arena and circle/square center obstacles | Shared geometry/physics, tests and UI | Implemented; do not reimplement from unchecked old boxes |
| Thread Growth with one initial thread, outer-wall growth | Controller and `thread_growth_test.dart` | Implemented; whole-suite coverage passes |
| User-configured changing arenas | `ArenaRotation`, per-profile settings, live integration tests | Implemented live; replay/export incomplete (A03) |
| Shared user/admin arena selector | Both call `showArenaSelectionDialog` | Implemented |
| Persistent admin arena authoring/catalog | No authored-arena persistence/editor found in reviewed source | Pending; existing geometry dialog is configuration, not creation of named arenas |
| Exact replay/video reproduction | Existing paths plus A02-A04/A10 | Partial; not complete |
| Capture actual watching UX without clickable controls | Export still uses its own 720x1280 composition | Controls omitted, but full presentation parity remains incomplete |
| Admin DVD watermark default `cha0s' Balls` | Export painter still hardcodes `dbsuarez.github.io` at line 28 | Pending; do not confuse arena/title or winner-card watermark with export watermark |
| BGM/SFX export choices and 10-minute warning | Dialog/exporter/mixer/backends and tests | Implemented in code; real codecs/playback/memory acceptance pending |
| Portable `.bw` import/export UI | JSON document model and `.bw` names exist; no file-open/save UI found in replay screens | Partial model support; server short-link sharing exists |
| Independent held artwork / fired skill composition | Current model/editor/composition tests | Implemented despite an older unchecked roadmap entry |
| Six-ball Android performance, cross-device and production acceptance | No independently executed device/production acceptance in this audit | Pending |

## Recommended implementation batches

Keep replay/video work last. Fix related mechanisms together, avoiding item-specific patches.

1. **Persistence and account recovery:** A01, A05-A09. Separate durable writes from preferences, retry adoption, repair offline transport/cache behavior, scope sensitive caches and protect shared settings from stale saves.
2. **Skill/editor reliability and identity:** A10-A12. Stable winning-move identity, common restore/save feedback, dirty-draft navigation. Preserve unified filters, visual previews and native cinematic behavior.
3. **Acceptance and documentation:** Real browser/Android checks, audio latency, memory/performance, account refresh/switching, cross-device edits and explicit migration status. Reconcile historical completion claims without inventing production verification.
4. **Replay/export final batch:** A02-A04 and A13; carry rotation and complete presentation choices, address historical rules compatibility, actual watching-layout parity, configurable export watermark and optional portable file UI. These are correctness and completion items, not reasons to rewrite the combat engine.

Each fix batch should convert the relevant audit observations into tests of the desired behavior. The existing suite passing alone is insufficient because the uncovered contracts were absent from it.

## Suggested manual acceptance matrix

- Browser at 360x800, laptop width and landscape: edit/save/reopen a built-in and a custom skill; change tabs; close a dirty editor; restore while offline; confirm numbers/icons remain readable.
- Same admin on PC/phone: remembered login after hard refresh/deploy; edit a custom group and skill; load the change on the other device; deliberately exercise a conflicting stale edit.
- Online -> offline -> online: cached own/shared groups, pack thumbnails and sprite revisions; failed first adoption followed by retry; full/blocked local storage.
- Threads, Thread Growth, Arsenal, All-Out and six-ball Mayhem: per-mode profile isolation, normal finish and environmental KO, respawn, custom-only/no-pickup loadouts, circle/square boundaries and center obstacles, shrinking and changing arenas.
- Damaging weapon/power/trap finishers: held motion and VFX order, duplicate skill labels with different artwork, target eligibility after KO, dual wield, reflection and native cinematic cleanup.
- Android/browser: cold first-shot and countdown audio; BGM/SFX/UX toggles/volumes; background/resume; six-ball memory and smoothness with custom animated assets.
- Replay final batch: saved/server replay opens, old-version fixtures, geometry at/after rotation, no-pickup links, audio/no-audio export, long-match warning, real MP4 playback and controls omitted.

## Reproduction and verification commands

Use Flutter 3.38.5 / Dart 3.10.4, matching current CI. Do not use the historical `-p vm` flag.

```powershell
$flutter = 'C:\Users\cha0s\fvm\versions\3.38.5\bin\flutter.bat'
$dart = 'C:\Users\cha0s\fvm\versions\3.38.5\bin\dart.bat'
& $dart analyze lib test integration_test tool
& $flutter test --no-pub --reporter expanded
node --test test/web/sprite_backup_test.cjs
$assetRevision = (git rev-parse HEAD).Trim()
& $flutter build web --release --no-pub "--dart-define=ASSET_REVISION=$assetRevision" --base-href /ballwars/
# Audit evidence archive includes this observation harness:
& $flutter test --no-pub build/whole_app_audit_probes_test.dart --reporter expanded
```

If the Windows system TEMP volume is full, select a writable temporary folder on a drive with space. The audit used `build/tool-temp` and explicit source analysis to avoid conflating its generated listeners with application code.

No commit, push, tag, release, production database write or image/audio generation was performed. The audit archive contains changed documentation and local evidence only; it is not a full-project replacement or an implementation patch.
