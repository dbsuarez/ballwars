# Batch 25: Subsequent swept-contact reflection

Fixed a Batch 24 gap: when a returning projectile struck a normal target and then a mirror/magnetic defender in the same tick, the subsequent defender previously only stopped the projectile and postponed reflection until the next tick. Now the second defender reflects immediately, consumes a mirror charge where applicable, records magnetic reflection history, transfers ownership, clears the old composed-skill issuer, and ends processing of the old swept segment.

Regression test added for second-contact mirror ownership transfer. Not executed: Flutter/Dart SDK unavailable. This is an incremental cumulative patch, not a finished persistent multi-target engine. Do not deploy.
