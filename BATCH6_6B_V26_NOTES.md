# Batch 6B v26 - synchronous event preview correctness

Fixed a concrete timing bug in event-focused Skill Demo replay: shot/hit/blast counters were sampled after activation, so events emitted synchronously by activation were missed. Counters are now sampled before activation, and one shared event checker runs immediately after activation and on subsequent simulation ticks. The ticker only starts if replay remains active. This avoids waiting for a second event when the first shot occurs immediately.

Cumulative patch based on v25. No gameplay engine or persisted schema changes. ZIP CRC validated. Flutter compilation and widget tests not run (SDK absent). Batch 6B remains unverified; do not treat as completed.
