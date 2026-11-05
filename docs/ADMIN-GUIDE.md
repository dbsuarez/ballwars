# Ball Wars Admin Guide

Generated from `assets/help/admin_guide.json`. Edit the catalog, then run `python tools/export_admin_guide.py` to refresh this reference.

Open Admin Settings > General > Admin Guide, or Read full guide from a skill editor info dialog. Editor info dialogs link to the relevant topic. Help is read-only and preserves the draft beneath it.

## Tutorials

- [Create your first skill](#first-skill)
- [Build a new skill instead of a variant](#new-composed)
- [Import an icon or animated sprite sheet](#sprites-tutorial)
- [Add an explosion that actually does damage](#explosion-tutorial)
- [Create and customize an arena](#arena-editor)

## How it works

- [How a skill is put together](#skill-pipeline)
- [Casting, projectiles and impact effects](#visual-events)
- [Mechanical effects versus visual events](#mechanical-steps)
- [Which preview should I use, and when is it saved?](#testing-saving)
- [Troubleshooting and current limits](#limitations)
- [What does Legacy mean?](#legacy)

## Parameter reference

- [Identity, behavior and availability](#identity)
- [Damage, healing and projectile mechanics](#mechanics)
- [Timing, repetition and native sequences](#timing)
- [Held item, grip and pickup artwork](#held-artwork)
- [Projectile artwork and launch point](#projectiles)
- [Visual Event placement, scale and transparency](#effect-placement)
- [Areas, damage radius and boundary guides](#area)
- [Bullet casings and shells](#shells)
- [Callouts, bubbles and sounds](#audio)
- [Sprites, animation frames and library assets](#sprite-reference)

<a id="first-skill"></a>
## Create your first skill

Duplicate a working weapon, change a few values, test it and save it as a separate skill.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### 1. Duplicate a working weapon

Where: Skill Management > skill menu

Open Skill Management, find Pistol and choose Duplicate. Name the copy Practice Blaster. A duplicate has its own identity; it does not replace Pistol.

### 2. Check identity and availability

Where: Identity

Open the copy. Keep Category as Weapon and start with its working behavior. Enabled makes a skill eligible for use; a saved match loadout may still need to select it.

### 3. Make one small mechanical change

Where: Mechanics

Change Initial / hit damage to 7. Keep the other settings for this first test. Damage affects gameplay; making the sprite bigger does not increase damage.

Example: Initial / hit damage: 7 life

### 4. Give it a recognizable look

Where: Visuals & Sprites > Artwork / Held & pickup / Projectiles

Choose an artwork tint, then use Grip preview to position the weapon in the ball's hand. Use Equipped display scale for the held artwork, and Projectile scale for the shot.

### 5. Add a callout and preview the sound

Where: Audio & Callouts

Set the activation yell and bubble style. Use the sound play button to audition the selected cue. These settings do not change the damage.

### 6. Test before saving

Where: Test & Preview

Open Skill Demo to activate the current draft and inspect its artwork stages. Use Live Arena to check actual collisions and damage. Previewing is not the same as saving.

What to check: The copy fires, its appearance differs from Pistol, and the hit damage follows your setting.

### 7. Save and check availability

Where: Editor Save

Press Save in the editor. A failed write is shown visibly; do not assume it saved until success. Reopen the skill to confirm it, then select it in the relevant game-mode loadout. Shared admin changes affect everyone using that library.

Related: [Identity, behavior and availability](#identity), [Damage, healing and projectile mechanics](#mechanics), [Held item, grip and pickup artwork](#held-artwork), [Which preview should I use, and when is it saved?](#testing-saving)

<a id="new-composed"></a>
## Build a new skill instead of a variant

Use a visual template, then define the behavior you actually want.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### 1. Create a new entry

Use the Create a completely new skill (+) button. Enter a name and choose a Visual template. The template supplies starting artwork; the entry is added separately.

### 2. Choose how it activates

In Identity, choose the category, behavior preset, trigger, targeting and delivery. Start with a compatible preset instead of switching every control at once.

Example: For an aimed shot: a weapon with aimed fire, nearest opponent targeting and projectile delivery.

### 3. Choose what it does

Configure damage, healing, statuses or ordered mechanical effect steps. If ordered steps are present, they take precedence over the older primary/secondary effect fields.

### 4. Separate held item from fired payload

A held knife can have its own artwork while a projectile-based skill supplies the fired payload. Use the editor's fired-skill/payload controls when available; changing only the icon does not turn a melee strike into a projectile.

What to check: Check the behavior preview and compatibility messages before trying a combination.

### 5. Test the real behavior

Use Skill Demo for quick iteration and Live Arena for collisions. Unsupported combinations/previews are disabled or explain why. Save only after checking both what you see and what the skill does.

Related: [Identity, behavior and availability](#identity), [Damage, healing and projectile mechanics](#mechanics), [Mechanical effects versus visual events](#mechanical-steps), [Casting, projectiles and impact effects](#visual-events), [Which preview should I use, and when is it saved?](#testing-saving)

<a id="sprites-tutorial"></a>
## Import an icon or animated sprite sheet

Save artwork in the library, then assign it to a skill.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### 1. Prepare the image

Use a transparent PNG or WebP for effects that should blend into the arena. A JPEG can have an opaque background. Keep source originals outside the normalized game assets.

### 2. Choose Sheet and Slices

In Sprites, import the image. A single icon is one cell; a four-frame animation can be one row and four columns. Set Sheet contains to One animation when the frames belong together.

### 3. Inspect every cut

Review the slice boxes and animation preview. Transparent gutters help prevent neighboring artwork bleeding. Trim to clean edges is optional; do not trim away an intended edge.

What to check: No neighboring icon appears in a frame; playback is centered and the background is transparent where intended.

### 4. Save to the library

Name the sprite clearly and save it. Saving a sprite to the library does not assign it to every skill. Do not confuse an icon with the whole animated sheet.

### 5. Assign the right stage

Choose the sprite for the skill's icon, held item, projectile or a visual event. Use opacity and placement controls for an effect that covers the face, instead of changing collision size.

Related: [Sprites, animation frames and library assets](#sprite-reference), [Casting, projectiles and impact effects](#visual-events), [Visual Event placement, scale and transparency](#effect-placement)

<a id="explosion-tutorial"></a>
## Add an explosion that actually does damage

Wire mechanics first, then choose the explosion artwork.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### 1. Start from a projectile skill

Duplicate a working projectile weapon or use a compatible projectile behavior. Select the intended payload if the skill fires another skill.

### 2. Enable the mechanic

Where: Mechanics

Enable Explosion on impact and configure the relevant damage and range/radius controls. An Explosion visual event alone only draws artwork.

### 3. Choose the effect

Where: Visuals & Sprites > Effects

Assign the Explosion visual event. Set its sprite, playback, scale, opacity and placement. Direct hit and Explosion are separate events: you can use different art for each.

### 4. Check both hit and blast

Test with more than one target in Live Arena. Check damage to the hit target and nearby opponents, then confirm the visual radius is understandable. Not every native behavior uses every generic option; check the editor's compatibility guidance.

Related: [Damage, healing and projectile mechanics](#mechanics), [Areas, damage radius and boundary guides](#area), [Casting, projectiles and impact effects](#visual-events), [Troubleshooting and current limits](#limitations)

<a id="skill-pipeline"></a>
## How a skill is put together

Identity, mechanics and artwork are connected, but each has a different job.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### Identity

The name, category and stable ID describe a particular skill. Duplicates and new skills are separate entries, even when they share the same base artwork or behavior.

### Mechanics

Trigger decides when it activates. Targeting decides who or where it aims. Delivery decides how the effect reaches that target. Damage, healing and statuses decide what happens.

### Presentation

Icon, held item, projectile, visual events, sounds and callouts describe how the action looks and sounds. A larger visual does not automatically get a larger hitbox.

### Native and composed skills

Existing native skills have their own behavior paths. Composed skills use the shared delivery/effect system. Behavior-specific controls and compatibility warnings matter; an exposed visual setting is not proof that every native attack uses the generic projectile path.

Related: [Identity, behavior and availability](#identity), [Damage, healing and projectile mechanics](#mechanics), [Casting, projectiles and impact effects](#visual-events), [Troubleshooting and current limits](#limitations)

<a id="visual-events"></a>
## Casting, projectiles and impact effects

Put artwork at the stage where you want it to appear.

`Held item -> Casting -> Projectile -> Impact / zone`

This illustrates a projectile attack. Other deliveries may skip stages. Mechanics decide what happens; artwork makes each stage visible.

### Casting

Plays on the caster when the move begins. Use this for a charge-up, not for a hit on the enemy.

### Muzzle flash and projectile trail

Muzzle flash plays at the hand when an aimed weapon fires. Trail follows a moving projectile; looping exhaust is a common use.

### Direct hit and Explosion

Direct hit plays when the skill hits an opponent. Explosion plays when an explosion event occurs. Choosing explosion artwork does not enable explosion damage.

### Ground zone and Arena boundary

Ground zone replaces a zone's artwork while retaining its collision/damage. Boundary artwork repeats along the real curved edge samples, facing inward.

### Owner status / channel and Target status

Owner status follows an active buff or channel until it ends. Target status follows the affected opponent until that status ends.

### Block, Defense break, Expiry and Discard

Block plays after a successful block/reflection. Defense break plays when the last defensive charge is used. Expiry plays when a zone/channel/status ends, not on death/reset. Discard plays when an equipped weapon is dropped or replaced.

### Shared definitions and per-skill bindings

An effect definition describes the artwork/playback. Its binding positions and scales it for a skill role. Check whether you are editing a shared definition or just the skill's placement before saving.

Related: [Visual Event placement, scale and transparency](#effect-placement), [Areas, damage radius and boundary guides](#area), [Sprites, animation frames and library assets](#sprite-reference)

<a id="mechanical-steps"></a>
## Mechanical effects versus visual events

Damage and artwork are different systems.

### Ordered mechanical effect steps

Use steps for a sequence of real effects: damage, DoT, heal, shield, freeze, stun, speed, pull, knockback, teleport, equip carrier or disarm. Each step can have relevant targeting, delay and parameters.

### Priority over legacy fields

A non-empty ordered step list takes precedence over the legacy primary/secondary effect fields. Edit the step list to change that skill's mechanics.

### Step timing

Delay schedules the step relative to activation. Duration and tick interval affect a status or DoT. Repeat count and repeat interval belong to the activation sequence; repeating artwork is not repeating damage.

### Visual event timing

A looping effect animates while its event is active. It does not schedule extra damage. For a burning zone, configure a damaging/DoT zone and assign its Ground zone artwork.

Related: [Damage, healing and projectile mechanics](#mechanics), [Timing, repetition and native sequences](#timing), [Casting, projectiles and impact effects](#visual-events)

<a id="testing-saving"></a>
## Which preview should I use, and when is it saved?

Use each preview for the question it can actually answer.

### Preview

The quick presentation preview shows the current draft's icon, effect color, callout/bubble and sound. It is not a full simulation of the attack.

### Skill Demo

Use the controlled scene to activate the draft and inspect held, casting, projectile and impact stages together. Speed and audio choices are remembered. Adjust the ball distance when the default scene is too close.

### Live Arena

Use Power-up Test to check actual movement, hits, damage and interaction with other skills. Tap a loadout icon to re-arm that slot; long-press to choose a different skill. Play does not automatically re-arm everything.

### Finisher

Available for supported damaging skills. Healing-only/utility skills do not get a finisher just because an icon exists. Finisher preview does not prove the normal arena attack works.

### Save and restore

Save in the editor persists through the supplied admin save callback. Save Library applies library/global changes. A write/conflict error means you must resolve it; a preview is not proof of persistence. The editor's Restore defaults changes the draft: inspect it before saving. The library's Restore original settings is a separate confirmed action and can persist immediately when the admin save callback is connected.

### Leaving safely

A dirty skill editor offers Save / Discard / Keep editing on exit. Opening this guide does not edit, save or discard the draft.

Related: [Create your first skill](#first-skill), [Troubleshooting and current limits](#limitations)

<a id="limitations"></a>
## Troubleshooting and current limits

Check the relevant runtime behavior before assuming a visual control changes the attack.

### Flamethrower: the stream does not start at my gun tip

The built-in flamethrower currently supports Projectile launch point for its continuous stream. Enable it in Appearance, move Forward/back to the gun tip, and adjust Sideways using both facing previews. Flame artwork and cone hit detection share this origin and follow the caster. The same emitter placement is reused by native Energy Wave and custom beam targeting. Automatic preserves the original ball-centered cone; older replays preserve their original origin.

What to check: A future configurable stream/emitter origin must move both the flame and its hit detection.

### My bigger artwork does not hit farther

Equipped, projectile and effect artwork scales are visual. Change projectile hit radius, melee reach or the appropriate area damage radius to change collision/reach, where supported.

### My new explosion only looks like an explosion

An Explosion visual event does not add damage. Enable a compatible explosion mechanic and check the actual damage/radius.

### I saved an icon but the skill still looks unchanged

A library asset is not automatically assigned. Check the icon, held, projectile and visual-event slots separately. Also check global versus per-skill effect mode and any Legacy values.

### The last edit did not save

Read the error. A connection, stale shared-settings conflict or missing migration must be resolved. Keep the draft, retry if appropriate, then reopen the saved entry to verify.

### The skill is enabled but never appears

Check the relevant game-mode loadout and custom-skill selection as well as Enabled. Player profiles remember their own pickup selections; library availability does not force selection into every profile.

Related: [Projectile artwork and launch point](#projectiles), [Visual Event placement, scale and transparency](#effect-placement), [Which preview should I use, and when is it saved?](#testing-saving)

<a id="identity"></a>
## Identity, behavior and availability

What the identity controls mean, and which settings determine the behavior.

### Name and description

Player-facing labels. The built-in description can be generated from its settings; a custom description is text you control. Renaming a duplicate does not change its stable ID.

### Category and Purpose

Category places the skill among weapons, power-ups, traps or arena traps. Purpose summarizes the configured effects (attack/recovery/defense/hybrid/utility); it is not a promise that merely changing a label adds that effect.

### Enabled and rarity

Enabled allows use of the skill. Rarity controls selection weighting/tier presentation; it does not directly increase damage. Match pickup selections are a separate choice.

### Visual template and behavior preset

Template supplies a starting look. A behavior preset supplies compatible mechanics. Replacing the icon alone does not replace delivery, targeting or the native runtime.

### Trigger and Trigger every

Pickup, aimed fire, collision, timer, damage taken or elimination determine the activation event. Trigger every is a timer interval in seconds and is shown for Timer. Damage-taken/elimination triggers need cooldown protection.

### Targeting

Self, nearest opponent, all opponents, chosen direction or arena location determine the intended target. Self + Damage can damage the owner; choose it deliberately.

### Delivery and Attack delivery

Delivery is the mechanical route: instant, projectile, area, beam, aura, orbit or boundary hazard. Attack delivery describes the action (swing, thrust, fire, throw, beam or summon). Compatible settings matter.

### Weapon class and handedness

Melee/ranged/hybrid describes the weapon style. One-handed/two-handed affects what can be equipped together. A two-handed weapon cannot occupy a normal dual-wield pair.

Related: [Build a new skill instead of a variant](#new-composed), [Damage, healing and projectile mechanics](#mechanics), [Mechanical effects versus visual events](#mechanical-steps)

<a id="mechanics"></a>
## Damage, healing and projectile mechanics

Gameplay values: test them in Live Arena, not only in an artwork preview.

### Initial / hit damage and All-Out damage

Where: Mechanics

Initial damage removes life in health-based combat. All-Out damage removes threads and is a whole-number value.

Example: 7 life removes 7 life on the supported hit event.

### DoT and All-Out DoT

Damage per tick, not total damage. DoT uses life/tick; All-Out DoT uses lines/tick. Tick interval and Duration determine the number of opportunities to apply it.

Example: 2 life/tick with a 0.5 s interval is nominally 4 life/second while ticks are active; actual first/last ticks depend on the skill event.

### Healing effect and Healing

Healing must be part of the intended behavior. Weapon healing is opt-in; adding a healing value alone is not a universal life-steal mechanic. Healing is measured in life.

### Projectile / hit count

Whole-number count. For a projectile delivery this controls the emitted shots; some native skills expose a more specific count label. Read that native help before treating it as bullets.

### Projectile speed, Spread and Maximum bounces

Speed is in arena/s. Spread is an angle in degrees around the shot direction. Maximum bounces is a whole-number limit for supported bouncing projectiles.

### Projectile hit radius and Melee reach

Physical reach measured in ball radii. These affect hits, unlike artwork scale. Hit radius is exposed for applicable composed projectile behavior; melee reach applies to contact strikes.

### Range and Projectile spin

Range is an arena ratio for supported behavior. Spin is degrees per second of visual projectile rotation; it is not knockback.

### Homing projectile and Return to launch point

Homing steers a compatible projectile. Return to launch point returns a compatible thrown projectile toward its original launch spot; it does not promise return to a moving owner.

### Explosion on impact

Enables the impact explosion mechanic where the behavior supports it. It uses the relevant range, damage, color, sound and shake settings. The Explosion visual event only chooses the look.

### Knockback strength and Effect strength

Knockback controls push strength; zero disables the supported generic push. Effect strength is a behavior-dependent multiplier: do not treat it as extra damage for every skill.

### Shield hits, Frozen-target damage multiplier and Frozen collision damage

Shield hits is the number of supported blocked hits/charges. Frozen-target multiplier scales damage to a frozen opponent; Frozen collision damage is a life value for that specific collision behavior.

Related: [Timing, repetition and native sequences](#timing), [Areas, damage radius and boundary guides](#area), [Projectile artwork and launch point](#projectiles), [Troubleshooting and current limits](#limitations)

<a id="timing"></a>
## Timing, repetition and native sequences

Seconds, activations and simulation steps are different units.

### Start delay

Seconds before activation begins.

Example: 0.5 s waits half a second before the action.

### Repeat count and Repeat interval

Repeat count includes the first activation. Repeat interval is the seconds between repeated activations.

Example: Repeat count 3 with interval 0.2 s means three activations, not one plus three.

### Cooldown

Seconds before the same trigger can activate again. This is different from the gap between repeats in a single activation.

### Duration and DoT tick interval

Duration is the behavior/status lifetime in seconds where supported. Tick interval is the seconds between DoT ticks; it must be positive.

### Clone appearance, Interval per strike and Clone disappearance

Native Shadow Clone phase lengths are expressed in simulation steps in their editor labels. They are not the general Repeat count or animation frame count. At the fixed 60 steps/s, 30 steps is half a simulation second.

### Tendril hold duration, Slam displacement and Slam velocity

Native Omega Tendrils controls. Hold duration is seconds; displacement is a ball-radius ratio; velocity is a multiplier. They do not change every other grab/slam behavior.

Related: [Mechanical effects versus visual events](#mechanical-steps), [Casting, projectiles and impact effects](#visual-events), [Which preview should I use, and when is it saved?](#testing-saving)

<a id="held-artwork"></a>
## Held item, grip and pickup artwork

Align what the ball is holding without changing its physical hitbox.

### Equipped display scale and Pickup artwork scale

Separate visual multipliers for the held weapon and the collectible artwork. A value of 2 is twice the configured artwork scale; it does not double collision or damage.

### Grip forward/back, Grip sideways and Grip rotation

Offsets use ball radii; rotation uses degrees. Use Grip preview to inspect both facing directions. Manual number entry remains available beside the sliders.

### Artwork Facing

Automatic preserves behavior inference. Mirror when facing left, Rotate with aim and Stay upright determine how held artwork follows the facing direction. Mirroring artwork is different from rotating it upside down.

### Track nearest opponent while equipped

Continuously turns supported held artwork toward a target. It does not by itself give a projectile homing behavior.

### Held attack animation

Slash, thrust, recoil, throw arc or none describe supported held-artwork motion. Choose a mechanical attack/delivery separately.

### Held horizontal/vertical and Effect horizontal/vertical offsets

Older attachment offsets are in ball-radius units. Prefer the current Grip/Visual Event placement previews for new authoring. A cosmetic offset does not move an unsupported native attack origin.

### Hand effect scale and Hand effect duration

Older held/hand visual controls. Scale changes the look; duration is seconds. For new effects, use the supported visual event and its hand attachment.

Related: [Projectile artwork and launch point](#projectiles), [Visual Event placement, scale and transparency](#effect-placement), [Troubleshooting and current limits](#limitations)

<a id="projectiles"></a>
## Projectile artwork and launch point

Set shot size, collision and launch placement independently.

### Projectile artwork and Projectile scale

Choose the flying image/animation and its visual size multiplier. Scale does not change Projectile hit radius. Select the actual projectile artwork, not the skill's collectible icon by accident.

### Projectile launch point

Enable the override to choose where supported projectiles, continuous flames and beams leave the ball. Forward/back and Sideways are in ball radii relative to aim. Automatic keeps the existing weapon behavior.

Example: Move forward to the barrel tip, then adjust sideways while checking both facing previews.

### Facing and sideways offset

A mirrored projectile origin keeps the intended visual side when facing left/right. Use both previews rather than adjusting only the right-facing sample.

### Fired skill / payload

When supported, the held skill can fire another skill's payload. The held item and emitted projectile can have different artwork. Select compatible projectile behavior and inspect the compatibility messages.

### Continuous streams are different

The flamethrower uses this launch-point override for both its continuous flame visuals and cone hit detection. The point follows the caster while the firing direction stays steady. Energy Wave also uses the saved emitter placement for its charge, sweeping beam and damage bearing. Custom beam delivery measures its hit ray from this point; its selected impact artwork remains at the target. This control does not turn an instant beam into a sustained attack.

Related: [Held item, grip and pickup artwork](#held-artwork), [Damage, healing and projectile mechanics](#mechanics), [Troubleshooting and current limits](#limitations)

<a id="effect-placement"></a>
## Visual Event placement, scale and transparency

Use the visual placement preview to position an effect; it does not move collision geometry.

### Effect definition and visual role

Select the effect's sprite/playback and bind it to a role such as Casting, Direct hit or Ground zone. Shared definitions can be reused; a binding positions that definition for a skill.

### Playback and Duration

Once, Loop, Hold last or Natural control animation playback. A definition duration is a cosmetic lifetime in seconds; Automatic follows the existing event lifetime. An effect can still stop when its owner/status/channel ends.

### Attachment

Automatic follows the role. Available overrides include owner, hand, impact, target or projectile, depending on the event. For example, an impact must not be attached as if it were a persistent owner buff.

### Forward offset, Side offset and Rotation

Use the placement preview and sliders, with manual inputs for precise values. Offsets are relative to the selected attachment; rotation is degrees. Facing controls whether the effect stays upright, follows direction or mirrors.

### Scale and Effect artwork scale

Visual multipliers. Definition and binding scales combine with the applicable skill/global visual scale. They do not enlarge the damaging area.

### Opacity / transparency

0 is invisible; 1 is fully opaque. Lower the effect opacity when it hides the ball's face. Transparency does not reduce damage.

### Artwork tint and Effect color

Tint changes sprite color, with white preserving original artwork. Effect color supplies the supported effect/fallback color. Neither changes damage or rarity.

### Screen shake

A visual impact-strength setting. It does not add force, damage or knockback. Check whether global/per-skill shake policy applies.

### Casting duration and Casting artwork scale

Legacy casting duration is a fallback when a Visual Event has no explicit duration. Casting artwork scale also applies to applicable casting Visual Events. Check the active event before expecting a legacy value to override it.

Related: [Casting, projectiles and impact effects](#visual-events), [Areas, damage radius and boundary guides](#area), [Sprites, animation frames and library assets](#sprite-reference)

<a id="area"></a>
## Areas, damage radius and boundary guides

Make the affected region readable without confusing it with the artwork.

### Damage radius / Custom area radius

Gameplay radius for supported area, aura or boundary-hazard delivery. The editor uses arena-ratio units; it is not the effect sprite's scale. Enable a custom override only when needed.

### Boundary guide style

Hidden, Dashed or Solid changes the displayed affected-area outline. A hidden outline does not disable the area's gameplay.

### Guide color and Opacity

Color and 0-1 opacity affect the boundary guide. They do not change the zone's damage or lifetime.

### Ground zone and Arena boundary artwork

A ground event follows the area/zone. Boundary events repeat along the real boundary and face inward. Choose the event that matches where the hazard lives.

### Duration and DoT

The zone's lifetime and mechanical tick settings determine the hazard. Looping the zone sprite only animates the artwork.

Related: [Damage, healing and projectile mechanics](#mechanics), [Visual Event placement, scale and transparency](#effect-placement), [Add an explosion that actually does damage](#explosion-tutorial)

<a id="shells"></a>
## Bullet casings and shells

Ejected casings are cosmetic; they are not extra projectiles.

### Enable shell ejection and Shell sprite

Choose the casing artwork for a supported gun. Unsupported weapons show a reason. The projectile sprite and shell sprite are separate.

### Shell size

Visual size multiplier for a casing. The editor supports up to 10. A larger shell does not create a larger shot or collision area.

### Shells per shot / volley and linked counts

Choose the cosmetic casing count or link it to projectile/hit count when that control is available. A volley is a firing event; changing shell count alone does not increase bullets or damage.

Related: [Projectile artwork and launch point](#projectiles), [Damage, healing and projectile mechanics](#mechanics)

<a id="audio"></a>
## Callouts, bubbles and sounds

Tune the presentation of an activation and test what you can hear.

### Yell

Text shown for the skill activation. Existing native yells can differ; a blank/general label does not describe every move.

### Callout style and Bubble shape

Normal, rare, epic and special are style/tier choices. Shout, speech, thought and radio describe the bubble shape. Use a shout for an attack and a calmer speech bubble for recovery if that is the look you want.

### Speech bubble duration

Seconds the bubble remains visible. The bubble adapts to its words; keep a short yell for readability in crowded matches.

### Sound cue and Play preview

Choose a supported cue and press Play to audition it. Audio mute/volume settings still affect what you hear. A sound cue is not generated speech and does not change mechanics.

### Global versus per-skill settings

When a global policy overrides callout, duration or visuals, the editor can disable the corresponding per-skill control. Check the Global tab before assuming a local edit is ignored.

Related: [Which preview should I use, and when is it saved?](#testing-saving), [Casting, projectiles and impact effects](#visual-events)

<a id="sprite-reference"></a>
## Sprites, animation frames and library assets

A sprite is reusable artwork; its assignment and revision matter.

### Rows, Columns and Sheet contains

Grid layout controls the cuts. One animation reads frames left to right, then top to bottom. Multiple separate sprites need their intended individual slices.

### Cell inset, gutters and Trim to clean edges

Inset moves cuts inward. Gutters keep neighboring art out of a frame. Trim is optional; inspect the preview so intentional pixels are not removed. Edge warnings identify possible bleed and are not a universal ban on art touching a cell.

### Frame rate, playback and preview

Animation timing controls how fast the frames are played. Four frames does not mean four projectiles or four damage ticks.

### Anchor and fit

Anchor positions the sprite within its frame; fit controls how artwork occupies the normalized frame. Use the preview to center the visible artwork. Use the skill's scale for its in-game display size.

### Library asset versus assigned asset

An uploaded sprite can stay in the library without changing a skill. Assign it to the intended icon, held item, projectile or visual event after saving it.

### Revisions and existing replays

Artwork revisions preserve references for replays. Avoid assuming that replacing one reusable asset changes only one skill: check its usage and the import/replace review.

Related: [Import an icon or animated sprite sheet](#sprites-tutorial), [Visual Event placement, scale and transparency](#effect-placement), [Projectile artwork and launch point](#projectiles)

<a id="legacy"></a>
## What does Legacy mean?

Compatibility controls are kept for existing skills, but are not the first choice for new effects.

### Existing data is preserved

Legacy values keep older skills and artwork readable. A Legacy tag does not mean the skill is broken or that its data should be deleted.

### Prefer Visual Events for new artwork

Use explicit Casting, Direct hit, Explosion, Ground zone and other current event roles. This makes ownership and timing clearer than overloading one old effect slot.

### Conversion needs review

Use the conversion action only after reviewing the effect/role it creates. Test in Skill Demo and Live Arena, then save. Do not replace a working native mechanic by changing only a legacy artwork field.

Related: [Casting, projectiles and impact effects](#visual-events), [Troubleshooting and current limits](#limitations)

<a id="arena-editor"></a>
## Create and customize an arena

Make a named map from an existing theme, configure its shape and arena traps, then make it available to players.

### 1. Start with a template

Open Admin Settings > Appearance > Manage arenas. Create an arena or duplicate a built-in template. Choose a unique name; hiding an arena removes it from new player selections while existing replays keep working.

### 2. Customize appearance

Appearance chooses the floor template and optional floor, detail and boundary colors. Media Library has the image controls: upload a PNG/JPEG/WebP, crop a square with one-finger pan and two-finger pinch (or sliders), and choose a 512px or 1024px maximum before upload. Choose an existing background with Library. You can adjust the saved image and dim it without reuploading; these settings affect this map only. Dimming leaves balls, walls, text and effects bright. Use template clears the image. Reset image adjustments restores the full saved image. Original cropped-away areas require selecting the original file again. Save the arena to publish image adjustments. The active boundary masks all artwork to circle/square.

### 3. Choose geometry and traps

Geometry opens the existing visual boundary/center-obstacle editor. Select a circle or square outer boundary, an optional center wall and its size. Obstacle sizes are limited to 12-34% of the arena radius to retain playable space. Pick the built-in arena trap set independently of the floor theme. Arena traps by default can be switched off; players may override trap toggles in Match Settings. Damage and timing come from Skill Management. Saving checks the narrowest passage at the configured minimum arena size. Starting a match checks its selected ball size too.

### 4. Save and choose it

Test opens your current unsaved map in Power-up Test, including its appearance and physical geometry. Returning keeps the draft. Save publishes it to the shared Custom tab in the arena chooser. The same dialog is used by administrator defaults, player Match Settings and Power-up Test. Geometry may be overridden for a match. The selected map is remembered separately for each game mode.

### Replay snapshots and arena changes

New matches, saved replays, .bw files and video exports keep the selected arena data. Editing, hiding or deleting the catalog entry does not change an existing match or replay. Changing-arena mode still cycles the built-in themes; custom styling applies when the cycle is at the starting map.

### If saving fails

Your draft stays open after a failed save. The backend requires migration 029_arena_catalog.sql for shared arena persistence. A missing column, stale settings or unconfirmed server write is shown as an error instead of silently saving only on this device.
