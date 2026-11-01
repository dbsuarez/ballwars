Ball Wars Batch 6B v47 - remaining two failures

Apply after v45 and v46. Contains only changed files.

1. Mechanical effects editor test: select Mechanics via its owning DefaultTabController rather than relying on a possibly intercepted tab tap.
2. Combine editor: display missing payload reference diagnostics even when another draft field is invalid. Save validation remains unchanged.

Validation: archive and static source checks only. Flutter/Dart SDK unavailable here; rerun flutter analyze and flutter test on your Windows machine.
