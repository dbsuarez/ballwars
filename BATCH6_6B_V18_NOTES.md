# Batch 6B v18: Skill Demo mode isolation fix

Selecting a different artwork focus now stops the previous replay and resets the isolated arena before changing mode. This prevents a Pickup preview or active animation from appearing as if it belonged to the newly selected mode. Does not modify persistent skill data or user preferences.

Cumulative over v17. ZIP CRC verified. Flutter SDK unavailable: analyzer and widget tests not executed. Remaining 6B integration and actual isolated animation playback still pending.
