# Ball Wars v1.14.50 RC02 — Full cumulative patch and verification report

## Baseline / application
- Contains all source/test payload files carried by **v1.14.50 RC01**, plus changes in RC02.
- RC01 itself was assembled using the **v1.14.41 shared full project baseline** with the supplied **v1.14.49 RC Repair 02** overlay. The result is intended to overlay your **current verified v1.14.49 release checkout**, not to replace your repository with the older baseline.
- This archive includes `.github/workflows/deploy-pages.yml` and `.github/workflows/release-apk.yml`. Review them before committing: it intentionally updates the existing pipelines, but does not introduce any new workflow or Flutter static-analysis CI step.

## Implemented in RC01 and retained
1. `pubspec.yaml`: `1.14.50+11450` (web version label for branch builds).
2. Held attack swing/reach strength and VFX scale (independently serialized, clamped, and exposed in Skill Editor).
3. Preview and arena painter support for both scales, retains Direct Hit Effects separately.

## Implemented in RC02
1. **Foreground VFX z-order:** Held Attack VFX queued after all equipped and transient melee artwork draws. Works for sprite and fallback-glyph weapons; applies per-hand placement and facing/mirroring. Attack VFX stays independent from Direct Hit Effects and damage.
2. **Recoil and throw arc modes:** Added `HeldAttackAnimation.recoil` and `.throwArc`, preserving all preexisting enum values and legacy default. Recoil pulls the weapon backward then resets. Throw arc has a forward-follow-through. Both are presentation-only; existing throw-in-flight hide/weapon removal rules remain authoritative. No new projectile or damage behavior.
3. **Editor and Grip Preview:** Both modes selectable; existing repeats, duration, swing/reach and VFX-size controls retained. Grip Preview attack-frame slider scrubs the same painter in both facing directions.
4. **Skill Demo attack timeline:** Added an `Attack timeline` control for weapons, opening the real Grip Preview painter and its frame scrubber for inspection. The preview does not mutate active gameplay or save edits.
5. **Web release version synchronization:** `deploy-pages.yml` runs on master pushes and stable `v*` tags; tag builds use tag-derived `--build-name`, branch builds use pubspec; keep existing tests, Pages publishing and Flutter 3.38.5.
6. **Android version numbering:** `release-apk.yml` preserves signing, tests, and release upload but uses the tag for both versionName and deterministic increasing versionCode: `major*1000000 + minor*1000 + patch`; v1.14.50 => 1014050. Allows existing app updates provided older installed versionCode is lower.
7. **Regression tests:** New mode motion and persistence test; explicit canvas image-order test confirms VFX painted after held sprite. Prior regression tests retained.

## Verification status
- Source-level review: performed for changed rendering path, enum persistence, selector wiring, and workflow logic.
- ZIP: entries unique; read CRC; every packed source hash checked against SHA-256 manifest.
- Flutter SDK not installed in this session. **No Flutter compilation, `flutter analyze`, Flutter test, or graphical run is claimed for v1.14.50 RC02.**
- User's `+1586 All tests passed!` applies to **v1.14.49**, not to this RC02 patch.

## Known limitations / behavioral notes
- The Skill Demo's Attack timeline is a **visual scrubber**, separate from the simulator's real-event playback. It opens Grip Preview rather than synthesizing damage events in Skill Demo.
- For ranged weapons, the existing fired-hold lifecycle may limit how long visual recoil is visible; this patch does not modify weapon lifetime to extend cosmetic animations.
- On release tags, Pages and APK release workflows run independently; check both workflows' test/build results. The web branch build may still reflect the pubspec version until the release tag run completes.
- Applying this cumulative patch to a source tree that has diverged from the supplied v1.14.49 RC Repair02 requires `git diff` review before release.

## Windows PowerShell verification (run from the verified v1.14.49 repo root)
```powershell
# Extract archive over your CURRENT verified source tree (not an older full baseline).
Expand-Archive -LiteralPath "BallWars_v1.14.50_RC02_COMPLETE_Weapon_Animation_VFX_ZOrder_CUMULATIVE.zip" -DestinationPath . -Force

git status --short
git diff --check
flutter pub get
flutter analyze
flutter test -p vm --reporter expanded
```

### Manual validation checklist
- Confirm UI Editor: Slash / Swing, Thrust, Gun Recoil, Throw Arc, None and Legacy; adjust sizes, repeats, frame.
- Preview both right and left facing. Verify VFX layers **above** weapon artwork, including dual-hand, and does not turn into direct-hit impact effect.
- In Skill Demo open Attack timeline and scrub 0%, 25%, 50%, 75%, 100%; verify recoil and throw motion visually.
- Verify a thrown boomerang follows the preexisting `hideHeldWhileThrown` setting and reappears correctly; ensure projectile/damage rules unchanged.
- Confirm GitHub Pages metadata displays v1.14.50 after the tag workflow. Verify Android build code 1014050 is greater than installed versionCode.

## Roadmap
| Scope | Implemented | Automated Dart tests executed | Release ready |
| --- | --- | --- | --- |
| v1.14.49 baseline carried | Yes | Previously 1,586 tests | User releasing separately |
| Correct Web display version | Yes | No | No |
| Held Attack VFX foreground z-order | Yes | Test added, not run | No |
| Swing/thrust, recoil/throw modes | Yes | Tests added, not run | No |
| Editor, Grip Preview and Skill Demo timeline | Yes | Not run | No |
| Web/APK tag version synchronization | Yes | CI not run | No |
| Runtime visual regression and release verification | Pending user review | Pending | No |

Suggested unique commit after local verification: `git commit -m "feat: v1.14.50 complete held attack foreground and release version sync"`.
Do **not** push a release tag until Flutter analysis, tests, and both-facing visual review are green.
