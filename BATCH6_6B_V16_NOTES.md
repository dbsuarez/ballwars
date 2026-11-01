# Batch 6B v16: Focus-aware demo actions

Added a contextual preview action to the five artwork focus modes. Pickup resets the isolated demo and places a pickup in the actual arena renderer. Casting, Equipped, Projectile and Impact replay the full actual skill simulation, without falsely claiming isolated VFX playback. Existing Edit artwork deep links and draft state remain unchanged.

Cumulative over v15. ZIP CRC and static checks passed; Flutter compilation and tests not run. Full mode-isolated playback and final 6B validation remain pending.
