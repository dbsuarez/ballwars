# Batch 6B v20: Arena mutation async guards

Direct arena shape, obstacle, spawn-pickup and clear-pickup controls now invalidate pending asynchronous replay preparation. They stop the ticker and clear stale preview errors, matching the mode-switch guard added in v19. This closes a race where a previously requested replay could activate after the user modified the preview arena.

Extended widget regression coverage for direct pickup clear and respawn.

Cumulative patch supersedes v19, includes previous 6A/6B changes. ZIP CRC checked. Flutter analyze and tests not run (SDK unavailable). Batch 6B is not yet complete.
