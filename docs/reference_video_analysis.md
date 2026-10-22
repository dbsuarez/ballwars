# Reference video analysis

Source: `docs/output_frames/fame_0001.jpg` .. `fame_1683.jpg` (576x1024, gitignored), with contact sheets at `C:\Users\cha0s\OpenBot\Shared\ballwars_montage\`. In frame pixels the arena is centered at about (287.5, 541.5) with a radius of about 242.5.

Two balls, USA (green) vs Russia (cyan). Russia wins at frame ~1620.

## 1. Core mechanic: rim slots and thread cutting (implemented)

All of the following comes from stepping through the frames. Implemented in `MatchSimulationController`.

- **Rim slots.** The rim has fixed, evenly spaced anchor slots, about 2 degrees apart (FFT of the line comb gives roughly 2.0 degrees, so we use 180 slots). Each slot is either free or owned by exactly one ball.
- **Lines.** Every owned slot is one straight line from its rim anchor to the owner's center. The anchor never moves; the inner end follows the ball. That is why a fan "sweeps" as the ball moves (frames 1-17: Russia's anchors stay on the upper rim while it travels right).
- **Start.** Each ball owns the half of the rim on its side (frame 1: Russia owns the upper half, USA the lower half).
- **Cutting.** A line is cut the moment the opponent's *body* overlaps it. The line disappears and its slot becomes free; nobody gains it. The cut edge lines up with the opponent's disk, so it reads like a shadow (frames 17-31: USA sits between Russia and the upper-left rim, and Russia's lines there disappear one by one; frames 110-135: USA drives through Russia's bottom fan and leaves a black wedge).
- **Gaining (wall hit).** When a ball hits the wall at a free slot, it claims the free slots from the contact point up to its own nearest line, and shows `+N LINES` in its color at the contact point. If the free run in a direction ends at an opponent's line, nothing is claimed that way. Cases checked:
  - f60: Russia hits the left wall and gets `+75`, filling the bottom arc back to its own lines on the right. The top-left run ended at a stray USA line, so none of it was claimed.
  - f84: USA hits the top-left wall and gets `+39`, filling the top arc back to its own lines on the upper right.
  - f833: Russia hits the bottom-right wall and gets `+34`, filling only toward its own lower-left fan. The free arc on the other side, which ends at a USA line, stays dark (f846).
- **Elimination.** A ball with zero lines is out (f1620: USA's last line is cut, USA dissolves, Russia wins).

### Things the earlier catalog misread

`deepseek_timeline_catalog.md` described several "features" that are really just this one mechanic:

- **"Beam mode" (f801-900)** is a ball that has only 1-3 lines left. It isn't a special attack.
- **"Two-blade fans / X / star silhouettes" (f951-1400)** are fans with a wedge cut out of the middle by the opponent passing through.
- **The "subtractive opponent cone" / dark wedge** is cut lines (freed slots) and the shadow the opponent's body casts.
- **"Fan axis re-aimed at the opponent" and "width scales with distance"** don't exist. Anchors are fixed; only the inner end moves.

## 2. Physics (implemented)

- **Speed.** Balls keep a constant speed for the whole match. Tracking both balls over frames 100-1400 gives about 0.05 arena radii per frame (median over 4-frame windows; quartiles 0.044-0.064). Playing it at one video frame per 60Hz step looked too fast in the app, so we treat the video as 30fps: 0.025 radii per step. At contact, speed passes from one ball to the other: f967 0.008→0.056 vs 0.077→0.040; f1374 0.006→0.048 vs 0.073→0.048; f1402 0.074→0.014 vs 0.058→0.078. The average speed never decays, so wall bounces lose no energy either. *Our build deviates on purpose:* full transfer felt like the hitting ball stalled, so a ball-on-ball hit keeps the elastic bounce directions but moves only 25% of the speed difference (`collisionSpeedTransfer`). Total kinetic energy is unchanged.
- **Size.** Ball radius is about 0.107 of the arena radius (26 px / 242.5 px).
- **Launch.** The balls start about 0.47 R out on opposite sides (f1). Both head about 45 degrees between "inward" and the same sideways direction (Russia down-right, USA up-right), so they converge as mirror images and first touch near the right rim around f19. We copy this for 2 balls.
- **Fairness (our addition).** Each match rotates the whole starting layout by a seeded angle. Each ball independently draws its start distance (0.40-0.55 R), speed (±10%) and tilt. The order in which balls are processed rotates every step. If the last two lose their final lines in the same step, the one with more lines at the start of that step survives (seeded coin flip on a tie). With 3 or more balls, a symmetric inward launch makes everyone converge on the center and wipe out in about 2 s, so they launch along their tangent with ±30° tilt instead. They also start slower (2 / ball count: 67% with 3 balls, 50% with 4), because more cutters otherwise end matches very fast. Measured over 1000 seeds per setup, wins by start position are even:

  | Balls | Wins by start position | Median match length |
  |---|---|---|
  | 2 | 512 / 488 | 8.2 s |
  | 3 | 357 / 333 / 310 | 19.9 s |
  | 4 | 251 / 234 / 269 / 246 | 13.1 s |

  None of these differences are statistically significant.
- **Slow motion.** The match runs at 0.25× while the last two balls remain and one has 10 lines or fewer. Normal speed returns if that ball gets back above 10.
- **Pacing.** The reference match runs about 1440 frames of normal play before slow motion starts. At 30fps that is about 48 s. For our current match lengths, see the fairness table below.

## 3. Effects (to do later)

- **Line growth on gain.** New lines don't appear all at once. They extend from the rim toward the ball over about 10-15 frames, so a dark disk around the ball shrinks as they arrive (f60-70, f84-90, f230, f833-846).
- **Line look.** 1 px hairlines in the owner's color. Brightness builds up near the ball where the lines converge, which gives the glow cone. No separate cone fill.
- **`+N LINES` text.** Small caps in the owner's color at the wall contact point. It holds for about 1 s, then fades.
- **Cut debris.** Small 1-2 px square dots burst near the cut, drift outward and fade over about 20 frames (f29-53, f115-125, f780-816).
- **Balls.** A circular flag image with a thin bright ring in the owner's color plus an outer glow. Some damage-stripe/banding is visible on the struck ball in the contact sheets.
- **Slow motion.** About f1441-1620, while one ball is down to a handful of lines: a `SLOW MOTION` badge (white caps, red dot, thin rule).
- **Loser dissolve.** The eliminated ball fades into a translucent disc over a few frames (f1620-1628).
- **Win card.** The winner's ball scales up to the center with the country name in heavy white caps, a small gold trophy/star, then `FOLLOW @...` and `NEXT BATTLE >` in small caps. No fade-out.
- **HUD.** `WHO WINS?` (heavy white caps) and `ROUND 1` (red) at the top for the whole video. No scores, percentages or health bars on screen.
