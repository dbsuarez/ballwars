# Ball Wars v1.14.69

Corrects two stale Match Setup test expectations that blocked v1.14.68 deployment and APK release. New matches intentionally use simulation revision 12 for independent random starting directions; the custom-map tests still expected revision 11. Their map defaults, geometry override, and per-mode persistence assertions are preserved.

## Verification

- All 101 checks across the 11 Match Setup test files and Power-up Test screen passed, including both reported failures.
- Flutter static analysis: no issues found.
- Repository-wide revision search found no other stale new-match revision-11 assertions. Explicit historical replay and death-animation fixtures remain unchanged.
- The earlier 77 simulation/replay checks passed for the unchanged runtime code. No new complete-suite run or phone verification is claimed.

2026-11-09: publish master and annotated tag v1.14.69 to retry web deployment and APK release. GitHub workflow completion remains a manual user check.
