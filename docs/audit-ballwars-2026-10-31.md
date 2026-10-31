# Ball Wars app audit — 2026-10-31

**Target:** `D:\Development\ballwars` @ `701ce5c` (working tree clean)
**Scope:** architecture, gameplay correctness, security/abuse, reliability, performance, release readiness
**Method:** read-only source review, static analysis, full test suite, release web build, Supabase migration review
**Not covered:** runtime testing on Android/iOS, live Supabase project state, manual browser sessions

---

## 1. Verification performed

| Check | Result |
| --- | --- |
| `flutter pub get` | OK (51 packages have newer, incompatible majors) |
| `flutter analyze` | 3 infos, no warnings/errors (see L6) |
| `flutter test` | 965 passed, 1 skipped, 2:06 |
| `flutter build web --release` | OK, `build/web` produced in 74.4 s; wasm dry run passed |

Toolchain: Flutter 3.38.5 / Dart 3.10.4.

The simulation engine remains the strongest part of the codebase: seeded determinism, fixed timestep with an accumulator cap, revisioned replay links, and dense regression coverage (dual wield, respawn effects, freeze lifetimes, skill slots). Nothing in this audit changes the conclusion that the engine is sound.

## 2. Status of the 2026-10-23 audit

| # | Finding | Status |
| --- | --- | --- |
| 1 | Admin sign-in can orphan the device's custom groups | **Partially fixed, regressed on web** — see C1 |
| 2 | Crafted replay links bypass match validation | Fixed (`ReplayLink.fromUri`, bounded parsing) |
| 3 | Public replay storage can be filled anonymously | Limits added but bypassable — see H1 |
| 4 | Offline sync blocks startup | Fixed — settings/packs awaited, images stream in behind Home |
| 5 | Image deletion not tied to DB deletion | Still non-transactional, now mitigated by an admin cleanup tool — see M1 |
| 6 | Exported web-video object URLs never revoked | Fixed (`web/video_export.js:133`) |

---

## 3. Findings

### C1 — Critical (web): the admin's "separate" Supabase client shares an auth BroadcastChannel with the device client, so signing in or out as admin destroys the device's anonymous session

`SupabaseAdminAuth` creates a second `SupabaseClient` for the same project (`lib/features/settings/data/app_settings_repository.dart:278-283`) with default auth options. GoTrue 2.27 starts a browser `BroadcastChannel` named `sb-<project-ref>-auth-token` in every client (`gotrue_client.dart`, `_mayStartBroadcastChannel`), and every received `SIGNED_IN`/`SIGNED_OUT` calls `_saveSession(session)` / `_removeSession()` and notifies subscribers.

Chain on web:

1. Admin signs in on the admin client → `notifyAllSubscribers(signedIn, broadcast: true)`.
2. The main client (`Supabase.instance.client`, the device's anonymous identity) receives the message and **replaces its own session with the admin session**.
3. `supabase_flutter`'s auth listener (`supabase_auth.dart`, `_onAuthStateChange`) persists that session to local storage, overwriting the anonymous token.
4. On admin sign-out the same channel broadcasts `SIGNED_OUT`; the main client drops its session and storage is cleared.
5. Reloading hits `main.dart:41-46`, which signs out any non-anonymous session on the main client.

Result: after an admin sign-in → sign-out on a web device, the anonymous account that owns the device's groups, saved groups and replay-creator rows is gone. The next group operation signs in a brand-new anonymous user (`custom_group_repository.dart:121-128`), so the player's groups disappear. If no group operation ran during the admin session, `adoptGroupsFrom` never ran either, so the groups are not even moved to the admin account — they are simply orphaned. Remember-me makes it worse: `recoverSession` in `_initialize()` also notifies subscribers, so the admin token is broadcast on every start before the user does anything.

This is exactly the failure the earlier audit fixed, reintroduced by the second-client design; it is web-only because `BroadcastChannel` is web-only.

**Why I rank it Critical:** silent, permanent loss of user-created content, with no in-app recovery path.

**Fix direction (choose one):**
- Stop depending on client isolation: save the device session JSON before any admin auth call and restore it on the main client immediately after every admin auth event, and skip the startup sign-out when the stored session is the admin's. Add a widget test that drives both clients.
- Or keep one client and make admin operations explicitly swap the session in a `try/finally` that always restores the device session.
- Or move admin writes behind an Edge Function that validates the admin JWT server-side, so no second client exists in the page.

**Before/after check:** on web, sign in as admin with Remember me, sign out, reload, confirm `myGroups()` still returns the pre-sign-in groups. I did not run this flow; the finding is from the code path in GoTrue 2.27.3 + supabase_flutter 2.18.3.

---

### H1 — High: the replay rate limit is per anonymous account, and anonymous accounts are free and unlimited

`enforce_replay_limit` caps 200 rows/day **per `creator`** (`supabase/migrations/007_replay_limits_and_image_cleanup.sql:19-32`), and `SupabaseShortLinkRepository.create` mints a fresh anonymous account on demand (`lib/features/replay_export/data/short_link_repository.dart:35-37`). Each row may carry a 1 MB `replay_payload` (`supabase/migrations/020_replay_documents.sql:12-21`), and rows are never pruned.

A script can create accounts in a loop and write hundreds of MB per hour, against the maintainer's Supabase quota, with no trace beyond rows. The per-account cap only stops a naive single-session client.

**Fix direction:** per-IP or per-fingerprint throttling at the edge (Supabase supports rate limits / captcha on auth), a project-wide daily byte budget checked in the trigger, or an opened/expired-replay cleanup job. At minimum, alert on `replays` growth and on anonymous-signup volume.

---

### M1 — Medium: `deleteGroup` removes the database rows first, so a storage failure is reported as a failed delete that actually succeeded

`custom_group_repository.dart:268-272` deletes `ball_groups`, then removes the images. If `_images.remove` throws (offline, storage 5xx), the user sees an error, retries, and gets "group not found" — while the images stay in the bucket until an admin runs `cleanUpUnusedImages`. This is the prior audit's finding 5, still open by design.

**Fix:** make the storage step non-fatal (log and return success) or delete images first and only then the rows (so a failure leaves a retryable group). Either way, don't surface a failure for a destructive action that already happened.

### M2 — Medium: admin mode depends on a live `is_admin` RPC per operation and silently falls back to the device account when it fails

`AccountAwareCustomGroupRepository._active()` calls `isAccountActive()` on every repository call (`custom_group_repository.dart:545-560`); `SupabaseAdminAuth.isAdmin()` swallows all exceptions and returns `false` (`app_settings_repository.dart:347-357`). Offline or during a Supabase hiccup, an admin's screens quietly switch to the device's anonymous repository: wrong group list, failed admin edits, or edits applied as the device identity.

**Fix:** cache the last known admin state for the session, distinguish "not admin" from "could not verify", and surface the latter instead of silently switching repositories.

### M3 — Medium: platform limits (50 groups, 40 balls, 200 saved groups) are count-then-insert and racy

`enforce_ball_limits` and `enforce_saved_groups_limit` (`001_ball_groups.sql:36-60`, `004_saved_groups.sql:29-39`) select a count and compare without locking. Two concurrent inserts both pass. Limits are advisory, not enforced.

**Fix:** serialize per owner (`select ... for update` on the parent row) or accept the overshoot explicitly in the docs.

### M4 — Medium: a ball's `position` comes from wall-clock seconds, so balls added in the same second tie

`custom_group_repository.dart:285` uses `DateTime.now().millisecondsSinceEpoch ~/ 1000`. Ordering is `order('position')` only (`:141`), and ties have no defined order, so a group's ball order can change between loads — visible in the group editor and in shared group links.

**Fix:** `max(position) + 1` for the group, or order by `(position, created_at, id)`.

### M5 — Medium: unguarded `firstWhere` in the end-of-match overlay

`arena_battle_screen.dart:408-419` and `:1402-1407` look up the winner/loser by id in `_state.balls` without `orElse`. The lookups run inside a `Future.delayed` + `setState`, so a miss throws after the header has already dimmed: the user gets no result card and no dissolve. Today the ids always match, but any future change to `contestants` vs. live state turns this into a reproducible crash.

**Fix:** `firstWhereOrNull` plus a fallback ball, or derive both from `_state.balls` first.

### M6 — Low: video export can hang if the encoder fails while its queue is full

`web/video_export.js:119-124` waits on `encodeQueueSize > MAX_QUEUE` without checking `s.error`. The encoder's error callback only stores the error; if the queue never drains, `addFrame` never returns and the export UI spins.

**Fix:** check `s.error` inside the wait loop and bail out.

### M7 — Low: rename dialog leaks a `TextEditingController`

`saved_replays_screen.dart:70-79` creates one per invocation and never disposes it. Small, but it accumulates listeners over a long session.

**Fix:** `final controller = ...; try { ... } finally { controller.dispose(); }` around the `showDialog` future (dispose after it resolves).

### M8 — Low: `_offline` treats every failure as "offline" and serves stale rows

`custom_group_repository.dart:246-258` falls back to the cache on any exception, including 401/403/RLS denials. Errors become invisible stale data; after an account switch the user can see rows from a previous session (the `groups:mine:<uid>` keys limit this to the same uid).

**Fix:** fall back only on timeouts/socket errors; rethrow auth and permission failures.

### M9 — Low: remember-me stores the full session JSON (refresh token included) in plain local storage on web

`app_settings_repository.dart:296-330` and `:378-390` persist the session via `DevicePrefs` (localStorage on web). There is no in-app XSS vector today, but any injected script or extension can lift a long-lived admin refresh token.

**Fix:** shorten the remembered lifetime, or keep the admin session in memory only on web.

### L6 — Low: CI runs tests but never `flutter analyze`

`.github/workflows/test.yml:19-24` and `deploy-pages.yml:29-31` run `flutter test` and a release build, so the three `curly_braces_in_flow_control_structures` infos (`skill_management_screen.dart:510`, `:632`, `skill_management_screen_test.dart:65`) accumulate unnoticed.

**Fix:** add `flutter analyze --fatal-infos` (or `--fatal-warnings`) to `test.yml`.

### L7 — Trivial: template leftovers in release metadata

`pubspec.yaml:2` still says `"A new Flutter project."`; that string can surface in store listings and package metadata.

---

## 4. Performance notes (no action required)

- `arena_battle_screen.dart:394` rebuilds a `SimulationState` every frame. It is an 8-field wrapper around existing lists, so the cost is one small allocation per frame — acceptable, but it could be a single reused object with mutable fields if profiling ever shows GC pressure.
- `_onTick` correctly avoids `setState` in favor of `ValueNotifier` and repaints only when the simulation stepped (`:84-93`), and the accumulator cap (`:726-730`) prevents the spiral of death.
- The recorded six-ball profile (`docs/SIX-BALL-PERFORMANCE.md`) shows 0.56 ms mean simulation and 21 ms offscreen raster/readback at 360×360; that is video export, not on-screen framing, and is documented as such.
- `web/video_export.js` keeps the encoder queue at 8 frames and revokes the previous blob URL, so memory stays flat across repeated exports.

## 5. Positive observations

- Replay parsing is defensive end to end: length cap, versioned markers, bounded nudge steps, bounded custom-skill ids, strict `kc` handling, explicit rejection of unknown combinations (`replay_link.dart:242-379`).
- Sprite atlas parsing validates every field and bounds counts before allocating (`sprite_atlas.dart:98-260`); imports are clamped to 256 frames / 64 sprites.
- RLS is designed rather than bolted on: owner-scoped groups and balls, admin policies, public-read replays with a per-user write cap, and immutable sprite revisions for old replays.
- Atomic preference writes are serialized (`device_prefs.dart`), and empty catches are confined to best-effort storage/audio paths.
- The offline store separates preferences from replaceable caches and migrates legacy keys.

## 6. Suggested fix order

1. **C1** — restore device-session isolation on web; this is data loss.
2. **H1** — close the anonymous-account rate-limit bypass, or at least add growth alerting.
3. **M1, M2, M5** — cheap, contained correctness fixes.
4. **M3, M4** — database ordering/limit fixes; M3 needs a migration.
5. **M6–M9, L6, L7** — hygiene.

## 7. Open questions for the owner

- Is admin sign-in expected on players' devices, or only on the maintainer's? That decides whether C1 should restore the device session or refuse admin sign-in on non-admin devices.
- Is the Supabase project on a paid plan with a storage budget? If not, H1 is a cost risk rather than an abuse risk.
- Should old replays expire? Nothing currently deletes them, by design ("links never expire").
