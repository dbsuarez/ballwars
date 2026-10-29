# Replay artwork revisions and authoring

## Immutable artwork

Migration `024_sprite_revisions.sql` archives atlas manifests and protects referenced sheets from deletion. The user confirmed it has been applied. Uploaded revisions use `custom.<atlas UUID>~<sheet revision UUID>.<sprite>`. Bundled artwork uses `built.<40-character git commit>.<sprite>` and historical files from that immutable repository commit. Production web and APK workflows supply ASSET_REVISION from github.sha.

Replay dependency manifests record these references and bounded embedded PNGs for generated icons. The `a.1` protocol marker makes older clients reject unsupported artwork-bearing replays. Old replays without a manifest retain legacy behavior; their original appearance cannot be reconstructed retroactively. Missing recorded artwork requires an explicit visible fallback for playback; video export refuses missing dependencies before encoding. This freezes artwork, not future changes to procedural choreography.

## Device budgets

Decoded memory estimates count unique registered frame pixels (width x height x 4), excluding decoder staging, heap and GPU overhead. Device cache choices are 64, 128 and 256 MiB. Unpinned custom/revision groups are evicted by recency; current match/export dependencies are pinned. Library metadata remains available after eviction.

Low, Balanced and Full density cap transient visuals at 64/192/512 and particles at 250/650/2000. Essential ground/status artwork remains visible. These controls do not change physics, damage, events or random draws. Export uses Full density.

## Authoring controls

Skill Demo remembers its last playback speed. Appearance > Effects provides a pinned two-direction placement preview, sliders plus manual numeric input for position/rotation/scale, and immediate tint/opacity/attachment feedback. Animated artwork can be scrubbed.

Projectile appearance has an automatic/custom launch point measured along and across attack direction in ball radii. The marker and actual projectile origin use the same settings. Automatic preserves legacy geometry.

Area-capable skills expose actual artwork preview, a physical radius percentage, boundary color/opacity and Hidden, Dash-dot or Solid boundary choices. Edit area artwork opens the relevant ground or explosion recipe. Artwork scale and physical radius are independent. Molotov and new composed skills use the same authoring controls; composed area activation artwork is cosmetic and does not add persistent damage ticks. Ordered mechanical composition remains Phase F.

Extended appearance snapshots use versions 10/11 only when these overrides are needed; earlier default snapshots remain compatible. Existing editor tabs and unsaved drafts are preserved.
