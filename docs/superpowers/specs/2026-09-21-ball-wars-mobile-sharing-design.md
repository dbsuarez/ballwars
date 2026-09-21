# Ball Wars: Mobile Support + Sharing/Public Gallery — Design

## 1. Context

The base simulator (physics, territory engine, canvas rendering, ball creator, match setup, battle screen) is specified in [`docs/CLAUDE_CODE_BALL_WARS_SPEC.md`](../../CLAUDE_CODE_BALL_WARS_SPEC.md). This document extends that spec with two additions the user requested:

1. **Mobile support** — the app must run well on iOS/Android in addition to web, not just be responsive CSS-style.
2. **Multi-user sharing** — users can share a completed match with friends, and browse a public feed of matches other users have shared.

This is a v1 design. Social features beyond browsing/replaying (likes, comments, push notifications, tournament/bracket mode) are explicitly deferred to a later phase (see §6).

## 2. Platform & Responsive Layout

- Same Flutter codebase targets Web (primary), iOS, and Android — no platform-specific forks of game logic.
- The arena screen is responsive:
  - The circular arena scales to the shortest screen dimension and stays 1:1.
  - **Portrait mobile:** score bar and controls stack below the arena.
  - **Landscape / web:** score bar and controls sit beside the arena.
- Touch targets (buttons, ball selection carousel) sized per mobile HIG/Material minimums (≥44x44 logical px) — the original spec's neon buttons need minimum-size adjustments for mobile.
- Image picking (`file_picker`) already works cross-platform (web bytes, mobile file bytes) — no change needed there beyond confirming the package's mobile support.

## 3. Determinism

Every source of randomness in the simulation (wall-bounce jitter angle, collision winner tiebreak, steal-amount roll, particle spawn variance) currently implied by the base spec as `random(...)` must instead draw from a single seeded RNG owned by the match:

```dart
// core/utils/seeded_random.dart
class SeededRandom {
  final Random _rng;
  SeededRandom(int seed) : _rng = Random(seed);
  double nextDouble() => _rng.nextDouble();
  int nextInt(int max) => _rng.nextInt(max);
}
```

- `MatchSimulationController` is constructed with a `seed` (generated via `Random().nextInt(1<<32)` at match start, or supplied when replaying).
- Physics engine and territory engine take a `SeededRandom` instance instead of calling `dart:math`'s global `Random()` directly.
- Given the same `{ballConfigs, seed}`, the simulation must produce bit-identical outcomes (same winner, same territory timeline) on any device. This is what makes replay sharing possible without recording video or frame data.
- **Constraint:** the simulation loop must be driven by a fixed timestep (not wall-clock delta) when replaying, so floating point accumulation doesn't diverge between the original run and a replay run. Live matches can still render at variable frame rate, but the underlying physics step should tick at a fixed `dt` (e.g. 1/60s), accumulating real elapsed time into fixed steps.

## 4. Backend — Firebase

- **Auth:** Firebase Anonymous Auth. Every install gets a stable `uid` on first launch, no login screen. (Upgrading anonymous → Google/Apple sign-in is a natural v2 addition, not required now.)
- **Firestore** — collection `matches`, one document per shared match:
  ```json
  {
    "id": "auto-id",
    "ballConfigs": [ { "name": "...", "primaryColor": "#...", "glowColor": "#...", "imageUrl": "...", "baseSpeed": 320.0, "mass": 1.0 }, ... ],
    "seed": 123456789,
    "winnerIndex": 0,
    "createdAt": "<server timestamp>",
    "ownerUid": "...",
    "isPublic": true
  }
  ```
  - Documents are small (no frame/video data), so this stays cheap even with a busy public feed.
- **Storage** — custom ball avatar images uploaded here at ball-creation time (for balls a user intends to use in a shared/public match); `ballConfigs[i].imageUrl` in the Firestore doc points at the uploaded file so any viewer's device can render the same avatar.
  - Locally-only balls (never shared) can keep using local `Uint8List` without ever touching Storage.
- **Security rules (v1):** anyone can read `matches` where `isPublic == true`; a document's owner (`ownerUid == request.auth.uid`) can create/update/delete their own documents. No writes to other users' documents.

## 5. Sharing Flow & Public Gallery

**Sharing:**
1. Match ends → winner modal shows a "Share" action (in addition to existing Next Battle/Replay).
2. On tap: if any ball in the match uses a local (non-uploaded) image, upload it to Storage first and swap in the resulting URL.
3. Write the match record to Firestore (`isPublic: true` by default, with a toggle to keep it private-but-linkable if desired).
4. Present a shareable link: `https://ballwars.app/match/{id}` (web fallback page) with app-link/deep-link handling so mobile opens directly into the app if installed.

**Receiving a shared link:**
1. App resolves `{id}` → fetches the Firestore doc.
2. Reconstructs `ballConfigs` (downloading avatar images from Storage URLs) and re-runs `MatchSimulationController` with the stored `seed`.
3. Because the simulation is deterministic, the replay is pixel-for-pixel the same match — the app doesn't need to store or stream any video/frame data.

**Public Gallery screen** (new, `features/sharing/presentation/public_gallery_screen.dart`):
- Queries `matches` where `isPublic == true`, ordered by `createdAt desc` (paginated).
- Each list item shows the contestants (avatars/colors) and the winner; tapping opens the battle screen in "replay mode" using that record's `ballConfigs` + `seed`.
- No interaction beyond browsing/replaying in v1 (no likes/comments yet — see §6).

## 6. New Directory Structure (additions to the base spec's tree)

```text
lib/
├── core/
│   ├── services/
│   │   └── firebase_service.dart      # Firebase init, auth bootstrap
│   └── utils/
│       └── seeded_random.dart
├── features/
│   └── sharing/
│       ├── domain/
│       │   └── match_record.dart
│       ├── data/
│       │   └── firebase_match_repository.dart
│       └── presentation/
│           ├── share_sheet.dart
│           └── public_gallery_screen.dart
```

Existing base-spec pieces that change:
- `arena_physics_engine.dart`, `territory_engine.dart`: take `SeededRandom` instead of ad-hoc `Random()`.
- `match_simulation_controller.dart`: accepts an optional `seed` + `replayMatchRecord` to support both fresh matches and replays through the same code path.
- `arena_battle_screen.dart`: supports a "replay mode" (loaded from a `MatchRecord`) vs "live mode" (freshly configured match); winner modal gets the new Share action.
- Battle screen / score bar / neon buttons: layout adjustments for mobile portrait per §2.

## 7. Phasing

- **v1 (this design):** base simulator + mobile-responsive layout on iOS/Android/Web + deterministic seeded simulation + Firebase-backed sharing + public gallery (browse/replay only, anonymous auth, no social interactions).
- **v2 (future, separate design pass):**
  - Likes/comments on public matches (adds Firestore subcollections + moderation considerations).
  - Push notifications via FCM (e.g. "your match got 10 views").
  - Tournament/bracket mode chaining multiple matches into an elimination bracket with an overall champion.

## 8. Testing Considerations

- Determinism must be verified explicitly: a unit test that runs the same `{ballConfigs, seed}` through the simulation twice (or on two different fixed-timestep tick counts) and asserts identical territory/winner outcomes.
- Firebase interactions (`firebase_match_repository.dart`) should be behind a repository interface so they can be faked/mocked in tests without hitting real Firebase.
- Manual verification on Flutter Web (`flutter run -d chrome`) and at least one mobile target (Android emulator or iOS simulator) for layout and touch-target checks.
