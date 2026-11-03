# Ball Wars projectile combat regression batch

Baseline: Patch 08 (v1.14.38 release baseline). All original project files and cumulative Patch 08 overrides are retained.

## Source audit
The four requested projectile-combat changes were already implemented in the Patch 08 source: impact admission bypasses firing cooldown but still enforces target/schedule limits; impact does not reset firing cooldown; volley admission uses actual remaining projectile capacity; and spread geometry uses admitted shot count with zero offset for a single shot. This batch does not duplicate or overwrite those working implementations.

## Added validation
- Live simulation regression tests for full composed volley geometry, single-shot straight aiming, and projectile hit while firing cooldown is active.
- Extended deterministic policy tests for cooldown independence, scheduling capacity, symmetric spread across seven volley sizes, partial admission across six capacity levels, zero spread, and invalid angles.

## Validation status
ZIP integrity checked. Flutter SDK is unavailable in this container, so tests are unverified until run in your environment.
