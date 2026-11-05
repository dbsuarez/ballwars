# Gameplay and arena additions — 2026-11-05

## Neo Threads: optional Cut Race

The main menu's Neo Threads opens the existing `threadgrowth` mode. There is no extra main-menu mode. With Cut Race off, its one-starting-thread, wall-growth, elimination and fixed-size rules are unchanged.

In Match Settings > Gameplay, enable **Cut Race**, then open **Cuts to win**. Enter any whole number from 1 to 1000, or use numeric up/down; the default is 50. These choices are remembered separately from other modes.

**Stay in play at zero threads** is an independent Cut Race option, default on. On: a zero-thread ball stays alive and may regain threads at the outer wall; reaching the target wins. Off: a zero-thread ball is eliminated; reaching the target or being the last survivor wins.

In Cut Race, physical and visible radius follow owned-thread count as a fraction of the configured maximum threads, increasing linearly from 0.5 to 1.5 times the chosen ball size. A stable ID resolves an equal same-step target crossing; an unequal crossing uses the highest cut total. Cuts and target appear beneath each live ball and the final tally uses cuts. Replay and video carry the same settings and body sizes.

## Mayhem and defeated balls

Mayhem accepts six, seven or eight selected contestants; Random still supplies six as the baseline. Add two more manually to try eight. Its duration, KO/death/health ranking, arsenal-only rules and user pickup selection remain in place.

In new matches, defeated balls become animated Ghost Orbs from the supplied four-frame sprite sheet that float upward and fade for 0.75 simulation seconds. Mayhem and Unlimited then respawn them with the existing full health/reset/invulnerability behavior. Pending respawns do not accidentally end the match as last-standing victories. Ordinary knockout ghosts animate during the existing result pause.

## Place balls in Power-up Test / Live Arena

Drag a ball directly in the test arena. The simulation temporarily stops while dragging, then resumes its prior paused/running state. Placement avoids the outer boundary, center obstacle and other ball; it preserves velocity, loadout, time, scores and idle pinning. It does not rearm anything. Regular match screens do not expose dragging.

## Uploaded arena backgrounds and safety

Admin Settings > Appearance > Manage arenas > Edit > Media Library > **Upload & crop**:

1. Choose PNG, JPEG or WebP (static, up to 16 MB and 16 megapixels, 8192px maximum side).
2. Set square crop with Zoom, Horizontal and Vertical sliders.
3. Choose a 512px or 1024px maximum. Smaller crops are not enlarged. The original file is untouched.
4. Upload the optimized PNG (maximum 4 MB) to the sprite library. Errors preserve the crop for retry.
5. Save the arena to publish the background assignment. Library reuses backgrounds; Use template removes the assignment.

The square background fills the selected boundary and is masked for circular arenas. Center walls, arena text and traps still render above it. Backgrounds use the existing storage, backup, offline cache and immutable revision/archive system; no additional migration beyond already-applied 029 is needed. Large-frame allowance is restricted to a single static square background; ordinary skill sprite limits remain unchanged.

Saving a map checks passage clearance at the configured minimum arena scale. Match Start checks its actual selected ball size (including the maximum Cut Race growth). New simulations also place starting/respawning balls outside walls and other balls without consuming extra random numbers.

## Compatibility and validation

New matches use replay revision 10 for the new modifier, expanded contestant counts, safe placement and delayed respawn. Historical revisions retain their previous behavior. Uploaded background dependencies are frozen for replay and video.

Automated validation covers actual user controls, remembered target=100, original growth behavior, both survival choices, cut credit/win, six/seven/eight contestants, safe deterministic spawn, test dragging, death timing, legacy respawn, upload/crop/resize failure and retry, background masking, and replay transport. Verification: complete suite 1,718 passed / one skipped, followed by 35 passing final map/schema checks. Whole-project lint is clean; release web compilation and phone-width crop/target controls and actual Ghost Orb rendering were verified. The initial parallel runner stalled; a clean two-worker full run completed successfully.

Manual acceptance still needed: actual browser/Android file pickers and upload, eight-ball visual density/performance, touch dragging, death animation and cross-device map artwork. No deployment or APK release is implied by local validation.

Ghost artwork: original `assets/sprites/Ghost Orb Idle Animation Sprite Sheet.png` preserved. `tools/photocraft/Export-DeathGhost.ps1` crops four isolated cells, resizes consistently and assembles the normalized transparent sheet through PhotoCraft. The runtime uses the animation and a code-drawn fallback if artwork is unavailable.

Maps with uploaded images use definition version 2 so older clients reject them instead of silently stripping the background during an edit. Template-only maps retain version 1. Update browser/APK clients before editing image-backed maps.

Deployment and signed APK release submitted as v1.14.57 on 2026-11-05. Workflow completion and device acceptance remain manual.
