# Batch 21: Overflow-safe All-Out projectile/thread crossing

Base: Batch 20 cumulative changed-file archive; production release baseline remains v1.14.38.

The projectile path/thread crossing predicate formerly multiplied unscaled cross products and then multiplied the orientation values. For finite but very large projectile displacements, those products could overflow to infinity or NaN, suppressing legitimate cuts. The new shared `segmentsProperlyCross` geometry predicate uses normalized determinants and compares orientation signs without multiplying them. It preserves strict interior crossing semantics (endpoint touches are not cuts) and rejects nonfinite inputs.

Regression tests cover very long crossings, parallel misses, endpoint contact, reversed thread orientation and nonfinite coordinates.

Validation: archive integrity and file inclusion checked; Flutter/Dart tooling unavailable here, so analysis and tests NOT RUN. This patch is not claimed to be production validated.

Apply the cumulative changed-files archive over the integrated project containing earlier patches; do not use it as a standalone project. All files from the Batch 20 cumulative archive are retained.
