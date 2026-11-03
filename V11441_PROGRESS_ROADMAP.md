# Ball Wars v1.14.41 Development Roadmap

Status: UNVERIFIED DEVELOPMENT CHECKPOINT. Do not deploy.

## Rarity regression repair
- Fixed null assertion in match tuning when custom rarity weights are all zero.
- Invalid rarity draft keeps admin tuning for rendering while existing validation blocks Start.
- Extended rarity widget test to check that the invalid draft produces no unexpected framework exception.

## Verification
- Flutter analyzer: NOT RUN (Flutter SDK unavailable here).
- Flutter tests: NOT RUN (Flutter SDK unavailable here).
- User must run flutter analyze and flutter test before deployment.

## Remaining v1.14.41 work
- Independent hand attachment, scale, offsets and effect settings.
- Shrinking arena controls consolidation and associated tests.
- Additional per-mode arena/trap integration tests.
