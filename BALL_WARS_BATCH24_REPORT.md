# Batch 24: center obstacle clipping for persistent multi-target contacts

This batch fixes a known continuation bug: a returning projectile hitting one target before a center obstacle could subsequently hit targets behind that obstacle in the same step. The continuation now uses the obstacle entry time as a cutoff and reflects at the wall if reached.

Regression scenarios added for both circle and square center obstacles. Tests were authored but not executed (Flutter/Dart unavailable). This does not complete the broader multi-target milestone. Do not merge without local verification.
