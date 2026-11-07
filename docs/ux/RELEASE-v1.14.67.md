# Ball Wars v1.14.67

Patch for the CI failure reported after v1.14.66.

## Fix

The old test used `compositionCompactVersion + 1` to represent an unsupported
snapshot version. That expression now evaluates to 14, a supported full snapshot
version introduced by opponent-priority settings. The parser was correctly
accepting it; the stale test assertion was wrong.

`maxSupportedVersion` now supplies the shared upper bound for the parser and
future-version rejection test. The old malformed-entry rejection check remains
intact. Separate positive checks verify the supported opponent-priority versions
14/15. No decoder validation was loosened to make this test pass.

## Verification and publication

The corrected test file passes all 12 checks, and static analysis reports no
issues. The complete final suite passed **1,808 checks**, with one existing opt-in
performance profile skipped and zero failures across all 249 ordinary test files.
One initial batch exited unexpectedly without reporting assertion failures; all
16 affected files passed in three smaller retry groups, including all 30 battle
screen checks. Effective totals replace partial counts rather than double-count
retries. [Executed inventory and evidence](../FULL-REGRESSION-v1.14.67.json).

Publication submission: 2026-11-07. Push master for web deployment and annotated
tag v1.14.67 for the existing signed APK workflow. The workflow derives Android
versionCode 1014067. Successful pushes trigger workflows, not proof of publication.
No workflow monitoring or phone installation is part of this patch.
