Batch 6B consolidated integration checkpoint v35

Added independent, optional Weapon Class (Melee/Ranged/Hybrid) and Attack Delivery (Swing/Thrust/Fire Projectile/Throw/Beam/Summon) taxonomy. Mechanical SkillDelivery remains unchanged. Both classifications persist through JSON and copyWith, with inferred defaults for legacy skills. Editor exposes both fields. Added exhaustive serialization and legacy compatibility tests.

This archive overlays the 2026-10-31 1648 full project and includes all v34 changes.

Verification: archive CRC and static source assertions only. Flutter/Dart SDK absent; network access to Flutter distribution unavailable. No compiler or test execution. Do NOT label 6B complete. Outstanding: integration testing and validation of real-arena preview, VFX migration parity, lifecycle across interruption/elimination, and full build. The new attack delivery taxonomy is descriptive metadata; it does not introduce new mechanical attacks.
