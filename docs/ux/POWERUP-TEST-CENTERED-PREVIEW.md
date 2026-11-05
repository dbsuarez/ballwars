# Centered Power-up Test preview

The full-width arena, status, finisher previews and playback controls now form one vertically centered group. Finishers sit directly below the arena. Reset and frame-step sit to the left of a centered 72px Play/Pause button; speed and arena selection sit to its right. Utility and finisher controls retain their compact 36px shape.

Short windows and keyboard insets allow the group to scroll instead of shrinking the arena. Collapsible rails, tap-to-rearm, hold-to-select and No item removal retain their behavior. Play does not automatically rearm.

Runtime previews:

- [390px phone](screenshots/powerup-centered-390x844.png)
- [320px phone](screenshots/powerup-centered-320x740.png)
- [Collapsed rail](screenshots/powerup-centered-collapsed-390x844.png)

Validation: 23 Power-up Test widget regressions passed, including group centering, horizontal button centering, the 72px target, full-width arena, short-window scrolling, item selection, dragging and finishers. Fixtures now use the actual portrait phone size by default; short-window behavior has an explicit case. Runtime captures passed; final analysis is clean and the production web build passed. No deployment or release is performed by this task.
