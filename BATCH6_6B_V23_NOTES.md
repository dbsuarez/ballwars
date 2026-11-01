# Batch 6B v23: Equipped mode inspection

Equipped preview now resets the real arena simulation to its equipped state without firing or advancing the simulation. Pickup continues to place a real pickup; Casting/Projectile/Impact continue full-skill replay. Added widget assertions for no shots, projectiles, or pickups during Equipped inspection. No gameplay data schema changes.

Validation: ZIP CRC passed. Flutter analyze/test not run (SDK unavailable). Cumulative over v22.
