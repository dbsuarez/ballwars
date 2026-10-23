# Ball Wars: power-ups and match modes

**Date:** 2026-10-23
**Status:** design, approved in conversation; ready for a build plan

## Intent

Ball Wars today has one mechanic: balls bounce in a circular arena, each owns a fan of threads (lines) to the rim, opponents cut threads by running through them, and a ball with no threads is out. The owner wants more variety and spectacle: power-ups that appear in the arena and turn the balls into little auto-battlers with guns, blades and tricks. It must stay a game you *watch*. Balls act on their own; nobody controls them.

The thread game stays. The player picks the kind of match before it starts:

| Mode | What decides the match |
|---|---|
| **Threads** | Today's game, unchanged. |
| **Arsenal** | Weapons only: no threads; each ball has a life bar (100 to 0). |
| **All-Out** | Both at once: threads *are* the life, and weapons cut threads. |

(Names: the owner's working name for Arsenal was "Weaponize"; "Arsenal" and "All-Out" were proposed and accepted. "Armed"/"Battle" were the alternatives.)

## Goals

- Two new modes, Arsenal and All-Out, selectable per match in Match Setup next to the existing settings. Threads stays the default.
- Power-ups spawn during a match, balls pick them up by touching them, and use them automatically.
- Everything stays **deterministic and fair** (see Constraints): replays, share links and exported videos reproduce a power-up match exactly; no starting position or contestant gets an edge.
- Readable spectacle: viewers can see a gun aim before it fires, bullets travel visibly, hits are obvious (flash, numbers or a thread burst), and the life bar makes the state of the match clear.

## Non-goals

- No player control, targeting choice or inventory UI.
- No new admin settings for this feature in the first version (spawn rate, damage etc. are constants).
- No new art pipeline: power-ups and weapons are drawn in code (CustomPainter), in the app's flat style.
- Not now: more power-ups beyond the eleven below. The owner wants more ideas proposed *after* this ships.

## Anti-goals (would make it a failure even if it technically works)

- The thread game changing in any way when the mode is Threads (same seeds must play out exactly as today).
- A mode that isn't fair across start positions, or one where matches routinely end in a few seconds or drag on for minutes.
- Unreadable chaos: too many objects, effects nobody can follow, or performance that undoes the recent low-end-phone work (no blur filters, batched drawing; see CLAUDE.md "Painting performance").
- Breaking replays: an old share link must still open as a Threads match.

## Rules (decided by the owner)

### Spawning

- A power-up appears **every 5 seconds** (game time) at a random spot inside the arena.
- **At most 3** power-ups are on the field. When a new one spawns and there are already 3, the **oldest is removed**.
- Uncollected power-ups do not expire on their own (only by the cap).
- *Builder's call:* spawn spots keep clear of balls and of other power-ups; the first spawn can come a bit before 5 s if that reads better, as long as it's seeded.

### Pickup and holding

- A ball picks up a power-up by touching it.
- A ball holds **at most one** power-up. Picking up another **replaces** the current one (the old one is lost).
- **All power-ups are single use.**

### Bumping

- In **Arsenal**, plain ball-to-ball bumps do no damage. Only a melee power-up (knife/sword, shield bash) turns a bump into damage.
- In **All-Out**, body contact keeps cutting threads exactly as in Threads mode.

### The power-ups (eleven)

| Power-up | Behavior |
|---|---|
| **Pistol** | Aims at an opponent, fires 1 round. |
| **Shotgun** | Aims, fires a fan-shaped burst of **10 pellets**. |
| **Gatling** | Aims, fires **10 rounds** in quick succession. |
| **Knife/Sword** | Damages an opponent on collision. Used up on its first hit, or lost if the ball picks up something else. |
| **Shield** | Blocks most of the next incoming attack, then breaks. If the holder bumps an *unarmed* opponent first, it does a **shield bash** (small damage) and breaks. |
| **Apple** | Life. Instant on pickup. |
| **Speed Boost** | The ball moves twice as fast for 3 s. |
| **Freeze Ray** | One shot; the target stops dead for 2 s. |
| **Bomb** | Dropped where the ball is; explodes about 1 s later and hits everything nearby, **including its owner**. |
| **Magnet** | Instantly pulls the **nearest power-up already on the field** straight to the ball (it is then picked up as usual). If the field is empty, it waits and pulls the next one to spawn. |
| **Ghost** | For 3 s the ball is **purely defensive and passes through other balls** (no bounce): it can't be hit or damaged, and in All-Out its threads can't be cut and its body doesn't cut anyone else's. |

Pistol, Shotgun, Gatling, Knife/Sword, Shield and Apple came from the owner; Speed Boost, Freeze Ray, Bomb, Magnet and Ghost were proposed and accepted.

*Builder's calls on guns:* automatic aim at the nearest opponent, a short visible aim beat (about 0.4 s, a line or reticle toward the target) before firing, bullets travel at a visible speed and can miss (the target keeps moving), bullets disappear at the rim. Gatling rounds are spread over about a second.

### Life and damage

- **Arsenal:** each ball has a **life bar from 100 to 0**; at 0 it is out.
- **All-Out:** **the threads are the life.** A ball's life is the number of threads it holds (shown on the scoreboard as today); it is out when its last thread is cut, exactly as in Threads.
  - Bullets **cut any opponent threads they fly through**.
  - A direct hit on a ball removes a chunk of its threads.
  - The knife/sword cuts threads on body contact (as bodies already do) plus a bigger chunk on hitting the ball.
  - The shield halves threads lost to the next attack.
  - The apple **claims free rim slots** (about +20 threads) with the existing "+N LINES" pop, instead of healing.
- *Builder's calls:* the actual numbers (damage per weapon, apple amount, chunk sizes). Starting points from the conversation: pistol hit about 8, apple about 25 life (Arsenal) / 20 threads (All-Out). Tune so matches feel neither instant nor endless (see Success).

### All-Out specials (accepted)

- **Thread snap:** a gun hit also cuts the target's threads nearest to where the bullet struck: a visible burst of severed lines.
- **Bomb blast:** clears every thread (from all balls) passing through the explosion; can flip a match.
- **Sword sweep:** for a moment after picking up a sword, the holder cuts every opponent thread it passes through: it rakes through a whole fan.
- **Apple grab:** as above (claims rim instead of healing).

## Constraints

- **Determinism** (project rule, CLAUDE.md "Determinism"): every random choice (spawn time/spot, which power-up, shotgun spread, aim jitter) comes from the match's `SeededRandom`, drawn only inside simulation steps, never per rendered frame. The outcome must depend only on `(contestants, seed, mode, ball size)`.
- **The look-ahead** (slow motion "before the win" and "settled" lines) replays the match off-screen; it must include power-ups so it still predicts the real finish. Its per-match cost should stay small (it currently takes tens of ms).
- **Slow motion per mode** (decided). Threads is unchanged. All-Out uses the admin setting as is: threads are the life, so "N lines left" carries over. **Arsenal** has no lines, so it always uses "seconds before the win". That's the admin's seconds if set, otherwise 1.5 s. If the admin set slow motion off (lines = 0 and no seconds), it stays off.
- **Fairness:** a win-rate-by-start-position probe over many seeds must show no bias for Arsenal and All-Out at 2, 3 and 4 balls (same method as the existing probes, recorded in `docs/reference_video_analysis.md`).
- **Threads mode is untouched:** with mode = Threads, every existing seed must produce the same result as before (existing determinism tests keep passing).
- **Replays:** the mode travels in replay links, short links and the video export. Absent means Threads, so old links keep working.
  - **Old installed apps must not play a wrong match** (decided). An APK from before this feature ignores unknown query parameters, so a plain `mode=` parameter would make it silently replay the seed as Threads. Instead, the mode goes **inside the ball list** as an extra token (for example `balls=m.allout,k.ulam/adobo,...`). Old apps reject unknown ball tokens, so they refuse the link and stay on Home.
  - Short links store the same ball list, so they behave the same. No new `replays` column is needed for the mode.
  - The new app reads the token and strips it before decoding the balls.
- **Performance:** follow the painting rules (no `MaskFilter` blurs, batched lines, cached text). Bullets and effects should be cheap to draw; keep object counts modest.
- **Text:** no en/em dashes in UI strings (owner rule).
- **Audio:** fits the existing 8-bit sound set; new sounds (shot, shotgun, gatling, slash, shield, bomb, pickup) are generated in `tool/sounds/make_sounds.py` like the others.

## Success

- The owner can pick Arsenal or All-Out, watch matches where power-ups clearly change the outcome, and finds All-Out exciting.
- Matches typically last somewhere around 15 to 60 seconds (same ballpark as Threads); no mode routinely ends before the first power-up matters.
- Fairness probes pass; Threads determinism tests unchanged; replays and videos of power-up matches match the live match.

## Calls made in planning (check these)

- Mode names: Threads / Arsenal / All-Out.
- Old apps refuse new-mode links (mode token inside the ball list) rather than playing a wrong match.
- Arsenal slow motion always uses "seconds before the win" (admin seconds, else 1.5 s).
- Guns auto-aim at the nearest opponent with a short visible aim beat; bullets travel visibly and can miss.
- Ghost passes through balls and is purely defensive; Magnet pulls the nearest power-up at once (owner agreed to both).

## Left to the builder

- Power-up and weapon visuals (icons on the field, how a held power-up shows on its ball, bullet/blast/freeze/ghost effects), within the flat style and performance rules.
- Where and how the life bar shows (on the ball, in the scoreboard, or both).
- Exact timings, speeds, damage numbers and spawn-spot rules, tuned by probes.
- Where the mode picker sits in Match Setup (owner: "the user can select what kind of match they want"), and whether it's remembered per device like the other setup choices (the existing pattern says yes).
- How the code is organized (e.g. a power-up system alongside the controller's step order), as long as the constraints hold.
