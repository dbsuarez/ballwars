# Skill Demo

Open **Edit Skill > Skill Demo** in the fixed bottom toolbar. The existing
**Preview**, **Live Arena** and **Finisher** actions remain available.

The demo receives the current unsaved definition and its library, including
custom skill IDs, payload choices, artwork, tint, sizes, grip/facing, opacity,
casting settings, callouts and sound. It never saves edits or changes match
preferences. Closing it returns to the same draft and editor tab.

## Controls

- **Use skill / Replay skill** starts a fresh, repeatable scenario. The caster
  starts equipped for weapon skills; nothing fires before pressing the button.
- **Pause / Resume** freezes the action for inspection. **Reset** returns to the
  equipped, uncast view.
- **Facing** swaps the caster/target sides; **0.25x / 0.5x / 1x** slows playback.
- **Test incoming hit** makes the target fire a real pistol shot. This shows
  shields, armor, reflection and Gremlin interactions. It does not bypass the
  firing or collision rules.
- **Sound** toggles demo audition locally without changing saved audio settings.

The stage uses the actual arena simulation and renderer, including cast artwork,
held items, projectiles, impact effects, trails, casings, recoil/discard, bubbles,
damage, healing, protection and status effects. Recovery starts with missing
caster health. Skill knockback can move the actors; they otherwise start still.

Four artwork references—**Casting**, **Equipped**, **Projectile**, **Impact**—stay
together below the stage. These show their first frame, tint and opacity. An
unassigned slot is labeled rather than substituted with invented artwork.
The stage itself plays the real animation, including the configured Sprite or
Vector effect preference.

## Scope

Activation is manual, including for custom timer/reactive triggers. Random
pickups and automatic innate custom triggers are disabled only in this demo.
Scheduled repeats, configured delays and DoT still run through the normal skill
engine. Use **Live Arena** to verify automatic triggers, movement, targeting
across multiple opponents, or full-match behavior.

Long demonstrations stop after 45 seconds with a visible notice. Replaying
resets health, equipment, effects and random seed. Demo state is never included
in normal matches or saved replays. No production simulation rules change.
