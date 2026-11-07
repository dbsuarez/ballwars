# Ball Wars v1.14.66

Submission: 2026-11-07. Master triggers web deployment; annotated tag v1.14.66
triggers the existing signed APK release workflow. Completion is checked manually.

## Changes

- Power-up Test uses the configured blood color and adds a compact loadout row.
- Approved 56 px circular Play/Pause button; playback above loadouts, finishers
  below them. Full-width arena, rearm and selection interactions remain intact.
- Skill Management > Identity > Opponent priority: nearest/farthest choice shared
  across applicable native and custom skills, including Buster Sword, single-target
  powers, composed effects, independent dual-wield selection and homing retargets.
- Historical defaults remain: Buster Sword farthest, other selectors nearest.
  Self, area and all-opponent effects retain their targeting semantics.
- Skill snapshots using opponent priority use full/compact versions 14/15 so older
  clients reject unsupported replay behavior. Existing snapshots remain compatible.
- In-app help, recommended model and runtime previews updated.

## Validation

- 23 Power-up Test checks and applied portrait capture passed; exact draft match.
- 18 dedicated shared-priority checks passed; editor save/reopen passed.
- Broad combat application (465), combat domain (84) and replay domain (48)
  regressions passed. The skill sweep had 597 passes and one local shader-loading
  error; all three tests in that preferences file passed in an isolated rerun.
- Final model/store/preferences run passed 53 checks. Help checks passed,
  generated documentation is current, and static analysis reports no issues.
- No new full-app suite or physical-device acceptance is claimed for this release.

No SQL migration is needed for opponent priority. Blood-color migration 013 was
already applied and verified during the preceding maintenance follow-up.

No workflow monitoring or phone installation. The signed APK workflow derives
Android versionCode 1014066 from the tag; successful push/tag does not prove
artifact publication or device acceptance.
