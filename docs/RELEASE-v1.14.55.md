# Ball Wars v1.14.55

Shared attack emitter, 2026-11-05.

- Reuse saved forward/sideways launch offsets across projectiles, native flame cones, Energy Wave and custom beam targeting.
- Expose launch-point controls for flamethrower, Energy Wave and custom beams in the skill editor.
- Share the configured origin between supported visuals and hit geometry; preserve mirrored vertical placement and moving-caster attachment.
- Preserve old continuous-attack origins with simulation revision 8 and retain historical projectile normalization.
- Update bundled help and roadmap, including user-confirmed migration 028 and video/file-picker acceptance.

Energy Wave retains its scripted unavoidable sweep. Custom beam targeting uses the shared origin; this does not introduce a new sustained custom-beam behavior. No new database migration is required.

Validation: 1,678 full-suite tests passed, one skipped; 62 final focused checks passed; maintained-source analysis clean; final release web build passed; both facing directions inspected with runtime screenshots. Android device acceptance remains manual.

Master/tag pushes trigger Pages deployment and signed APK publication (1.14.55 / 1014055). Workflow completion is not monitored.
