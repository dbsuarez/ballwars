# Batch 1: persistence and account recovery

Date: 2026-11-04. Source baseline: `91ab400` / v1.14.51. This is a cumulative changes-only working-tree patch, not an APK release.

## Completed implementation

- [x] **BW-A01:** Durable replay reads/writes propagate failures and confirm stored content. Replay mutations serialize their full read/modify/commit sequence; new records use unique IDs. A damaged/unreadable list is preserved rather than replaced by an empty list. The primary list is authoritative; an empty list cannot resurrect the legacy single-replay pointer.
- [x] **BW-A01 UI:** Failed saves, deletes and renames show errors. A failed replay-list load shows Retry instead of an endless spinner. Home retains access to the replay screen if the list cannot be read. The current match stays available after a failed save.
- [x] **BW-A01 platform boundaries:** Browser replay writes cannot fall back to memory and claim durable success. Native file reads distinguish missing files from permission/I/O failures. Best-effort cosmetic preferences keep their nonfatal behavior.
- [x] **BW-A05:** Failed adoption attempts are removed from the pending cache; concurrent requests share the same attempt. Successful adoption is scoped to source/target account IDs, reset on observed logout, and checked again before account results are returned after an in-flight identity change.
- [x] **BW-A06:** Group queries use cached results after HTTP client connectivity failures, socket failures or timeouts. Authorization/schema/server-policy exceptions remain visible.
- [x] **BW-A07:** A replaceable-cache write failure does not discard fresh server groups.
- [x] **BW-A08:** All-groups caches are scoped by user ID. Older unscoped admin cache entries are never reused by the new read path.
- [x] **BW-A09:** Shared settings saves compare the existing `updated_at` token before updating. A stale save is rejected visibly rather than overwriting newer settings. A successful response advances the local token; reload enables a deliberate retry. New timestamps advance monotonically even if the local clock is behind the loaded timestamp.

No new Supabase migration is required: `app_settings.updated_at` already belongs to migration 002. Live production schema was not queried. Conflicts are rejected, not automatically merged; keep the draft and reload current settings before retrying. Older app builds do not send the new conflict condition, so use updated clients when checking concurrent edits.

## Regression coverage

New tests in `test/batch1/` cover full/unconfirmed/unreadable storage; corrupt-list preservation; concurrent add/rename/share mutations; queue recovery; blocked browser storage; legacy-list migration/deletion; adoption retry/coalescing/account switching; HTTP offline fallback; authorization-error propagation; fresh data with failed caching; private-cache isolation; stale settings conflicts and reload/retry; and visible replay-list/delete failure recovery.

Verification: **1,626 tests passed, one skipped**, including **16 new Batch 1 tests**. Source/test/tool analysis is clean. The release web build also passes. Existing audit observation probes describe the old baseline and are not the acceptance tests for this fixed batch.

## Remaining work

Batches 2-4 remain in [the audit roadmap](WHOLE-APP-AUDIT-ROADMAP.md). This batch does not change targeting, replay format, rotation snapshotting, empty-pickup decoding, finisher identity or cinematic behavior. Replay/export improvements remain last.

Actual Android/browser storage pressure, account switching and cross-device conflicting saves remain hands-on acceptance items. Local mocks verify contracts but do not certify production installation or database policy state.

## Validation and deployment commands

Use the installed Flutter 3.38.5 SDK; do not use the unsupported `-p vm` flag.

```powershell
$flutter = 'C:\Users\cha0s\fvm\versions\3.38.5\bin\flutter.bat'
$dart = 'C:\Users\cha0s\fvm\versions\3.38.5\bin\dart.bat'
& $dart analyze lib test integration_test tool
& $flutter test --no-pub --concurrency=2 --reporter expanded
$assetRevision = (git rev-parse HEAD).Trim()
& $flutter build web --release --no-pub "--dart-define=ASSET_REVISION=$assetRevision" --base-href /ballwars/
```

For a later authorized deployment, review the exact patch files, commit only those files, then push `master`. Do not stage unrelated deleted archives/reports or use `git add -A`. No tag or APK release is implied by this patch. Preserve the current master-only Pages and tag-only APK workflows.

## Validation evidence

- `build/batch1-full-tests.log`: final full suite, `04:00 +1626 ~1: All tests passed!`.
- `build/batch1-final-analysis.log`: `No issues found!`.
- `build/batch1-web.log`: **passed**, release web build, current full HEAD artwork revision and `/ballwars/` base path.
- The first default-parallel full run exhausted the local Dart VM's available memory. The final full run used `--concurrency=2` and completed successfully. Earlier focused runs found and corrected queue-completion, unique-ID and retry-view issues before final verification.
- New replay-screen tests also caught a Future-returning `setState` callback in reload paths; those callbacks now update state synchronously for retry, rename and share refresh.

No app version bump, new database migration, commit, push, tag, APK creation or deployment has been performed for this patch. Existing unrelated deleted files and the user's handoff are preserved.
