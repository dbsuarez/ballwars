# Ball Wars Test Feedback Patch 06

Root cause: the built-in Boomerang has `returnsToOrigin=true` and `delivery=null` because its native throw is not a composed skill. `SkillAdvancedCompatibility.issues` incorrectly required `SkillDelivery.projectile` for all returning weapons, including native built-ins. The editor included these issues in its Save-button disable condition. The same false-positive could affect native homing weapons such as Rocket Launcher.

Fix: allow null composed delivery for native, non-composed skills while continuing to reject incompatible explicit or composed deliveries. Preserve all existing skill numeric validation and persistence logic.

Includes cumulative Patch 05 files plus the compatibility fix. No test files modified. Flutter SDK unavailable in this environment; please run the targeted test and full suite locally.
