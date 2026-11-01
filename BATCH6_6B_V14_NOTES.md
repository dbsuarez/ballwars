# Batch 6B v14: legacy VFX cleanup with explicit bindings

The opt-in conversion now retires obsolete Casting and Impact sprite fields even when an explicit Visual Event binding already exists. Existing bindings are preserved and no unnecessary effect definition is created. This removes redundant legacy artwork without changing effect precedence. Added a regression test for preservation, cleanup, and repeated conversion.

Cumulative over v13; Flutter compilation and widget tests not run. ZIP integrity checked. Batch 6B remains incomplete.
