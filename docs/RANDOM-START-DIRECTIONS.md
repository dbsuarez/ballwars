# Independent starting directions

New matches and Power-up Test use simulation revision 12. Each ball independently chooses a heading across the full 360 degrees, rather than sharing a clockwise/counterclockwise launch pattern. This includes upward, downward, sideways, and diagonal starts.

Only the initial direction changes. Starting positions, speed distribution, wall reflections, and collision physics retain their existing rules. A ball keeps moving normally after launch; its direction is not continuously randomized.

The match seed reproduces the same starting headings. Replay links support revision 12; recordings from revisions 1?11 retain their original launch behavior.

Validation covers independent headings in every quadrant, unchanged initial speeds, deterministic seeds, and an eight-ball replay simulation round-trip.
