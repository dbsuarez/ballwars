# Patch 04 cumulative

Apply over Quality Pass 02; includes patches 01 through 03.

Change: open the six-section Skill Editor as a dedicated MaterialPageRoute instead of a modal bottom sheet. This removes the bottom-sheet overlay that was observed intercepting the Save Library button, and gives the editor full viewport height. Existing editor Save and Close use Navigator.pop unchanged.

This is a source-level candidate fix. The most recent user-provided test excerpt does not include the failing test name; no claim that it fixes the remaining failure is made. Flutter/Dart SDK unavailable, so no analyzer or test execution. No test assertions modified.
