# Ball Wars test feedback patch 02

Based on analyzer output (two remaining curly-brace infos) and batch6d_test(1).log.

Changes:
- Add braces to the two flagged control-flow sites, including adjacent unbraced guards.
- Respect explicitly selected non-projectile delivery in behavior diagnostics; native inherited fireProjectile defaults no longer suppress warnings for homing and projectile count.

Log reports 10 failing tests: five melee reach, one behavior diagnostics, four Skill Management widgets. Diagnostics change targets the single diagnostics failure. The five melee reach and four widget failures are NOT claimed fixed. No Flutter SDK available here; tests and analyzer not run.

Apply this source-only patch on top of feedback patch 01 (and Quality Pass 02).
