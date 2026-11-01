# Batch 6B v13: Visual Event save ordering

Fixed both the direct-save and draft-save editor paths so migrated/new Visual Event definitions are installed before a skill referencing those effects is installed. This avoids transient unresolved effect references when saving a newly migrated skill. The existing compatibility checks and persistence remain in place.

Cumulative over v12 and the 6A baseline. ZIP CRC checked; Flutter compilation and tests not run.
