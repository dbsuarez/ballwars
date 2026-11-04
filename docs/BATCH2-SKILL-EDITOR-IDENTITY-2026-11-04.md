# Batch 2: Skill editor reliability and stable finisher identity

Date: 2026-11-04. Baseline: `91ab400`, v1.14.51. Local implementation; no push or release.

## Completed

- **A10:** Accepted damage and thread cuts retain the exact skill ID and definition for the winning move. Live finishers, the gallery and exported finishers use this captured presentation instead of searching by display name. Identically named skills remain independent. Payloads, delayed effects, repeats and damage over time retain their issuing skill. Environmental hits and body collisions cannot accidentally select a custom skill with the same name.
- **A11:** Library-level restore waits for persistence before replacing the visible skill. Failure keeps current settings and shows an error with Retry. A busy overlay blocks conflicting actions while restore is pending.
- **A12:** Closing a changed skill or using system back offers Save, Discard and Keep editing. Failed saves retain the draft; invalid drafts cannot be saved. Clean, reverted and successfully saved drafts close without a warning. Edits made during an outstanding save remain unsaved afterward.

The existing unified library, tabbed editor, preview, live test and finisher workflows remain available. These changes do not alter damage rules, physics, seeded randomness or replay document formats. Historical replay targeting/rotation corrections remain in Batch 4.

## Regression coverage

Sixteen new tests in `test/batch2/` cover duplicate-name identity and tint, payload/direct/DoT/delayed attribution, native built-in overrides and thread cuts, environmental attribution, live/gallery cinematic identity, restore retry, draft validation, system back and edits during an outstanding save. Existing skill/editor, composition, combat and export tests also run with the full suite.

- Full suite: **1,641 passed, one skipped** (`build/batch2-full-tests.log`).
- Final native thread-cut forwarding change and its new regression: **8 identity tests passed** (`build/batch2-identity-final.log`). This includes the additional sixteenth Batch 2 test added after the full run started.
- Source/test/integration/tool analysis: **no issues** (`build/batch2-analysis.log`).
- Release web build: **passed**, using the full baseline HEAD for `ASSET_REVISION` (`build/batch2-web.log`).
- `git diff --check`: **passed**. Existing unrelated local changes/deletions were preserved. No ZIP was created.

## Remaining acceptance

Actual phone/browser visual checks, Android system-back behavior, cross-device synchronization and production verification remain in Batch 3. A passing widget test is not hands-on device acceptance. No migration is needed for Batch 2.

The [current roadmap](WHOLE-APP-AUDIT-ROADMAP.md) also includes the separate Flame rendering feasibility study requested by the user. It is an experiment after correctness fixes, with measured visual/replay/performance comparisons and a go/no-go report before any migration. No Flame dependency was added.
