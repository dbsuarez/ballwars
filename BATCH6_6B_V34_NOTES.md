# Batch 6B v34: Incoming-hit preview state isolation

Fixes a race between the incoming-hit action and event-focused preview. The
incoming-hit action now cancels the prior event target and ticker, resets the
frame clock, and only starts the ticker when the simulation is actually playing.
If preparation or activation fails, the simulation stops consistently.

This is cumulative over v33. No gameplay model or persistence changes.
Validation: ZIP CRC and source assertions passed. Flutter SDK unavailable;
Flutter analyze and widget tests have not been run. 6B is not certified complete.
