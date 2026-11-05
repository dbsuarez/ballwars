# Replay compatibility policy

Batch 4, 2026-11-04. Simulation rules travel in the replay's `v.N` marker, including when the query is stored in a `.bw` document or behind a server short link.

- Unmarked historical links use revision 1.
- Revisions 1-6 use the historical nearest-target policy: contestant-order tie breaking, no retention/hysteresis, and no preference for targets visible around the center wall. Homing retargeting preserves historical candidate order too.
- Revision 5 introduced square geometry; revision 6 permits center obstacles. The decoder now accepts both (revision 6 was previously generated but rejected).
- Revision 7 introduced: ID-based deterministic ties, target retention and obstacle-aware preference. Prediction/look-ahead and exported simulations retain the match's recorded revision.
- Revision 8 introduced: configurable flamethrower launch origins shared by rendering and cone hit detection. Revisions 1-7 keep their ball-centered flame origin even if a saved skill contains launch offsets. Automatic origin preserves the existing cone in every revision.
- Custom-map matches use revision 9 and carry a validated immutable map snapshot. Older clients reject this revision. Replay documents and video retain the saved map independently of catalog edits/deletion. Center obstacle scale is encoded without decimal rounding.
- Unknown future revisions are rejected with a visible unsupported/invalid replay explanation rather than being interpreted using today's rules.

## Historical limitation

Some published builds changed targeting without changing the replay revision. Their identical revision numbers do not identify which algorithm created a link. Revisions 1-6 now consistently use the recoverable historical nearest-target algorithm; perfect reproduction of every intervening published build cannot be promised without its originating rules/build snapshot. This change does not fabricate that missing provenance.

## Arena changes and pickup selection

`rottheme`, `rotshape` and `rotsec` preserve enabled rotations and their interval. Absent keys keep the original non-rotating behavior. Invalid toggles/intervals are rejected. Rotation uses simulation time and the existing timed-match interval policy, including when exported.

`w.0` explicitly disables all built-in pickups. A missing weapon selection retains the older all/default semantics. `cs=` can independently select custom skills, including custom-only matches. These choices survive local storage and the versioned server/file document.

## Evidence

Tests cover contestant-order ties/retention, accepted revisions 1-7, malformed/future markers, saved/server-document custom-only spawning, post-transition state and final winner parity, and an actual exported frame after rotation compared pixel-for-pixel with the corresponding live rendering.

## Revision 10

New Match Setup matches use revision 10. It records the Neo Threads Cut Race modifier, cut target and zero-thread survival preference, supports 7/8-ball Mayhem, retains uploaded background revision dependencies and uses safe spawn placement. It also delays endless respawns for a 0.75-second death ghost. Previous revisions keep their original spawn/respawn rules. Cut Race is an option of existing `threadgrowth`, not a new mode token. Future/older clients reject unsupported revision 10 rather than silently changing these rules.
