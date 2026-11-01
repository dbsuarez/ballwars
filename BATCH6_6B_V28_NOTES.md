# Batch 6B v28: replay failure recovery

Cumulative over v27, containing all earlier Batch 6A and 6B source changes.

- A failed asynchronous replay now stops the ticker and simulation, clears its pending event and stale event message, and leaves an actionable error.
- Explicitly identifies event-focus timeouts as absence of an *observable* event, rather than absence of the underlying gameplay effect.
- Preserves the existing generation guard so a stale failed request cannot interrupt a newer replay.

Validation: archive CRC, replacement assertions, and Python structural checks. Flutter SDK unavailable; no Flutter compilation or widget test execution. Batch 6B remains unverified.
