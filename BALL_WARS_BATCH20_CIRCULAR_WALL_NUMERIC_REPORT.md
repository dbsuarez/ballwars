# Batch 20: Circular center-wall numeric safety

Production baseline: v1.14.38 (user-confirmed released). This is a cumulative patch-only development checkpoint building on Batch 19.

The circular center-wall entry guard previously squared the projectile's starting radius and the expanded wall radius, and used an unscaled dot product to distinguish inward and outward rim travel. Finite large coordinates could overflow these intermediate values and misclassify wall contact. The guard now compares overflow-resistant lengths and uses normalized directions for the rim test. The contact normal is also normalized safely.

Added diagonal inward/outward rim regression tests without altering existing tests. Existing Batch 18 axial rim tests remain included.

Verification: static source comparison and ZIP integrity only. Flutter and Dart are not installed in this environment; analyzer and tests were not run. Apply this patch over the integrated prior project, preserving all other source files. This archive is not a verified complete diff against the original production baseline.
