# Ordered mechanical effects (Phase F)

Implemented 2026-10-29. No database migration is required.

## Editing a skill

Open a composed skill in Skill Management > Identity > Behavior. Select **Use ordered effect steps** to convert its original primary/secondary effects, or **Edit N effect steps** for a converted skill. Native built-ins keep their signature implementation; create or duplicate a composed skill to author a sequence.

The dialog presents one step at a time. Select its numbered tab, add up to eight steps, move it earlier/later, or remove it. Add step stays visible on phones. Use steps returns the draft to the Skill Editor; **Save** in that editor persists it. Cancel discards the dialog changes. Switching steps preserves unsaved inputs. Removing all steps restores the retained Legacy primary/secondary controls.

Each step chooses its effect and target, then only relevant parameters are shown as Label | Control rows. Blank numeric values inherit the skill default (displayed as a hint). Zero is an explicit value, including zero knockback. Invalid values keep the dialog open and identify the affected step.

Example: damage 7 HP to Hit targets, heal the Caster by 3, then wait 0.2 seconds and stun Hit targets for 0.4 seconds. Self-healing happens once per activation, including an all-opponent activation.

## Targeting and timing

| Setting | Behavior |
| --- | --- |
| Hit targets | Original collision or activation recipients; dead/ghost targets are skipped |
| Caster | The living caster, once |
| Nearest opponent | Resolved when the step executes, not when the sequence began |
| All opponents | All living, non-ghost opponents when the step executes |
| Target range | Optional 5?100 percent of arena radius, measured from the caster; blank is unlimited |
| Wait after previous | 0?10 seconds after the previous step starts; equal-time steps retain list order |

Activation Start delay runs before the sequence. Repeat count/interval repeat the entire sequence; intervals are measured between sequence starts, so long sequences can overlap. DoT duration/ticks are independent for each DoT step. These are finite operations, not a programmable loop or a recursive skill graph.

Available steps: damage, DoT, healing, shield charges, Freeze, stun, speed, pull, knockback, teleport, equip carrier and disarm. Freeze includes independent vulnerability/collision parameters. Parameters retain normal match-mode behavior, including existing crowd scaling and thread damage.

## Runtime safeguards

- At most 8 steps, global repeat count at most 10, and existing projectile/DoT caps.
- At most 256 queued step events and 64 deferred activation/repeat records. A sequence that cannot reserve its pending step records is rejected before applying its immediate operations. DoT saturation may reject a DoT operation independently.
- Mayhem limits all-opponent repeat chains to 5, including an all-opponent step inside an otherwise single-target skill.
- Caster death cancels delayed operations and DoT. Respawn clears associated pending activations/steps/DoT before the ball rejoins. Temporary stuns do not cancel an already launched sequence.
- Returning projectiles retain their existing per-contact-session hit guards. Each accepted collision runs the ordered sequence once; lingering overlap does not execute it every frame.
- Saturation increments the Skill Demo inspector's budget-rejection count and shows an EFFECT LIMIT callout for ordered effects/DoT. Import rejects extra steps, unsupported fields/recursive references, unknown types/targets, non-finite numbers and out-of-range timings.

## Mechanics versus artwork

Each step supplies mechanics; sprite pixels, tint, artwork scale and missing art do not supply damage, knockback, reach or status duration. Step recipes reuse the skill's visual bindings and events.

For ordered projectile skills, Damage & Timing has **Projectile hit radius** in caster-ball radii (0.01?3, default 0.15). This physical radius is independent of Appearance > Projectile scale. Skill Demo collision outlines use the same physical radius. Homing and return flight honor configured projectile speed. Hook, Rocket and Prism templates do not inject native pulls, extra blast artwork or split-child projectiles into an ordered skill. Use explicit mechanical/visual settings instead.

Damage steps inherit the skill's impact knockback unless overridden. If the sequence includes a separate Knockback step, inherited damage knockback is suppressed; an explicit per-damage-step override remains honored. This avoids accidentally applying the same inherited force twice.

## Persistence and compatibility

`SkillEffectStep` is a bounded typed model stored as `effect_steps`. A library containing steps/new projectile geometry writes full schema 12 or compact schema 13. Older versions remain readable; unchanged legacy libraries retain their original schema and execution path. Original primary/secondary definitions are kept until explicit conversion. Duplicate, Restore defaults, JSON import/export, direct editor Save and replay snapshots carry the steps.

The delivery, trigger, carrier and projectile payload remain skill-level settings. This phase does not add arbitrary scripts, per-step projectile emitters, recursive payload calls or a new visual-art library. Existing reusable visual recipes remain separate from mechanical steps.

## Verification

Regression coverage includes save/reload and actual arena execution, full/compact/replay snapshots, equal-time ordering, dynamic retargeting, single self-heal across multiple opponents, independent DoT schedules, delayed explosion repeats, death/respawn cleanup, queue saturation, returning-projectile contact guards, native-carrier isolation, configured flight speed, and artwork/physical-radius independence. The dialog was rendered at 390 x 844 and checked with keyboard insets. Android phone acceptance and Phase E phone performance measurements remain deferred/manual.
