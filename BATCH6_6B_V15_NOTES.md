# Batch 6B v15: Retire deprecated Casting and Impact artwork selectors

- Removed legacy Casting artwork and Impact / effect artwork selection rows from the Legacy editor subsection.
- Kept the legacy values in the data model and editor draft for backward compatibility; migration remains available through Convert legacy VFX.
- Existing Visual Event bindings retain precedence; old saves are not silently modified.
- Projectile artwork remains editable in Legacy for now.
- No changes to gameplay logic.

Validation: static source assertions and ZIP CRC passed. Flutter compilation and tests not run. This is an intermediate checkpoint, not a 6B release.
