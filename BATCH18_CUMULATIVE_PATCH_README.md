# Ball Wars cumulative patch through Batch 18

Base: confirmed deployed/released v1.14.38.

This patch is a compact reconstruction of the projectile reliability changes from available full archives (Batches 03–17) plus the user-provided Batch 18 changes-only archive. Batch 02's known lifecycle source/test/report files are included. The exact original v1.14.38 file-by-file baseline was not available for a complete diff, so this package is NOT guaranteed to contain every earlier unrelated change between v1.14.38 and Batch 03. Do not use it as a replacement for an existing fully integrated Batch 17 checkout unless you have that checkout or full archive available.

Extract over the already integrated Ball Wars project, preserving paths. Do not delete other files.

Validation status: ZIP integrity checked; Flutter analyze/test not executed.

PowerShell validation and deployment (run from project root after reviewing changes):

```powershell
flutter analyze
flutter test --reporter expanded
git add -A
git commit -m "fix: integrate projectile center wall boundary contacts batch 18"
git push origin master
```
