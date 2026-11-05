# Ball Wars v1.14.57

- Neo Threads optional Cut Race with a configurable 1-1000 cut target (default 50), optional survival at zero threads, and progressive thread-based body size. Existing rules remain unchanged when the modifier is off.
- Mayhem supports six, seven or eight selected balls.
- Test-only ball dragging preserves equipment, motion and time while avoiding walls and other balls.
- Arena background upload with square crop, zoom/position controls and pre-upload resizing to a 512px or 1024px maximum. Backgrounds reuse the sprite library and immutable replay artwork revisions.
- Safe spawning and minimum-arena passage checks.
- Supplied four-frame Ghost Orb animation floats upward and fades before a 0.75-second delayed Mayhem/Unlimited respawn.
- Updated Help and reconciled roadmaps. Replay revision 10 protects new rules; background definition version 2 protects image-backed maps from older editors.

Validation: full suite 1,718 passed / one skipped; final map/schema suite 35 passed; lint clean; release web build passed; phone-width UI and ghost rendering inspected. Real-device acceptance remains manual.

No new database migration is required beyond already-applied 029. Update web/APK clients before editing image-backed maps.

Master push triggers Pages deployment. Tag v1.14.57 triggers the signed APK workflow and GitHub Release. Workflow completion is left to the user.
