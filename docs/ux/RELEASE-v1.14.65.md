# Ball Wars v1.14.65

Deployment/release submission: 2026-11-07. Master triggers the web deployment;
annotated tag v1.14.65 triggers the existing signed Android APK release workflow.
Workflow completion and device acceptance are checked manually by the user.

## Changes

- Both portal teleport endpoints follow the configured portal artwork scale in
  sprite and vector rendering. Swap Cannon burst sizing is preserved.
- Supplied death ghost artwork is 20% larger, compensating for transparent margins
  so its visible body is approximately the defeated ball's size.
- New matches and Power-up Test use replay revision 11, adding a six-step death
  hit stop (100 ms at normal playback speed). Ghosts keep floating; simultaneous
  deaths share one pause. Respawn timing remains unchanged.
- Older replays retain their previous simulation behavior; revision 11 sharing
  and parsing are supported.

## Validation

- 14 portal/painter checks passed, covering sprite and vector sizing.
- 145 death-animation, respawn, replay/export, match-setup and Power-up Test
  checks passed.
- Flutter analysis reports no issues; Git whitespace checks passed.

Successful pushes trigger publication but do not establish workflow completion
or APK availability. No workflow monitoring or phone installation is performed.
The APK workflow derives Android versionCode 1014065 from the release tag.
