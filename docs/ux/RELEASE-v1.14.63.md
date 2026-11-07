# Ball Wars v1.14.63

Deployment/release submission: 2026-11-07. Push master for the web workflow and annotated tag v1.14.63 for the existing signed Android APK workflow. Workflow completion is checked manually.

- Phase C: shared game styling for Skill Library, six-section Skill Editor, Ball Studio and Skill Demo; labeled filters, rarity frames and short-window scrolling.
- Phase D: battle/replay styling, full-window centered winner panels, visible winner titles and reachable actions, responsive landscape controls.
- Phase E: remaining player screens, bounded motion and reduced-motion support, static backdrop paint isolation and responsive Home artwork decode requests.
- Arena area, gameplay, deterministic replay data, settings and export choices retained. No new runtime packages, schemas, artwork or signing/workflow changes.

Validation before the version-only publication change: 1,770 full-suite tests passed / one existing opt-in skip; 54 final focused/visual checks passed, additional larger-text captures passed, analysis clean and release web build passed. Detailed evidence and screenshots: [Phase C](PHASE-C-REPORT.md), [Phase D](PHASE-D-REPORT.md), [Phase E](PHASE-E-REPORT.md).

Actual phone/browser acceptance and phone performance remain manual. Successful push/tag triggers workflows; it does not prove the APK is published or production is accepted. No device installation performed.
