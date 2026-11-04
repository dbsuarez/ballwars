# Replay compatibility policy

Batch 4, 2026-11-04. Simulation rules travel in the replay's `v.N` marker, including when the query is stored in a `.bw` document or behind a server short link.

- Unmarked historical links use revision 1.
- Revisions 1-6 use the historical nearest-target policy: contestant-order tie breaking, no retention/hysteresis, and no preference for targets visible around the center wall. Homing retargeting preserves historical candidate order too.
- Revision 5 introduced square geometry; revision 6 permits center obstacles. The decoder now accepts both (revision 6 was previously generated but rejected).
- New matches use revision 7: ID-based deterministic ties, target retention and obstacle-aware preference. Prediction/look-ahead and exported simulations retain the match's recorded revision.
- Unknown future revisions are rejected with a visible unsupported/invalid replay explanation rather than being interpreted using today's rules.

## Historical limitation

Some published builds changed targeting without changing the replay revision. Their identical revision numbers do not identify which algorithm created a link. Revisions 1-6 now consistently use the recoverable historical nearest-target algorithm; perfect reproduction of every intervening published build cannot be promised without its originating rules/build snapshot. This change does not fabricate that missing provenance.

## Arena changes and pickup selection

`rottheme`, `rotshape` and `rotsec` preserve enabled rotations and their interval. Absent keys keep the original non-rotating behavior. Invalid toggles/intervals are rejected. Rotation uses simulation time and the existing timed-match interval policy, including when exported.

`w.0` explicitly disables all built-in pickups. A missing weapon selection retains the older all/default semantics. `cs=` can independently select custom skills, including custom-only matches. These choices survive local storage and the versioned server/file document.

## Evidence

Tests cover contestant-order ties/retention, accepted revisions 1-7, malformed/future markers, saved/server-document custom-only spawning, post-transition state and final winner parity, and an actual exported frame after rotation compared pixel-for-pixel with the corresponding live rendering.
