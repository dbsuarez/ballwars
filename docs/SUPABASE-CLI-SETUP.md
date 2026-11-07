# Supabase CLI setup

Verified on 2026-11-07 with Supabase CLI 3.0.0 via `npx.cmd --yes supabase`.

- Project: **ballwars**, production, `ehepdokwjmudssgkxoij`.
- This Windows checkout is initialized and linked. CLI credentials remain outside
  Git. Local link metadata in `supabase/.temp` is ignored.
- Login uses the owner's **Chrome** account. The Opera GX account only had access
  to another project. Use `npx.cmd --yes supabase login --no-browser --agent no
  --output-format text`, then open the emitted URL explicitly in Chrome. Never
  commit tokens or verification codes.
- On another checkout, use `npx.cmd --yes supabase link --project-ref
  ehepdokwjmudssgkxoij`; committed config does not include credentials or a local
  link. Use the full command on one line.

## Completed production reconciliation

The original CLI history was empty because SQL had been applied manually. The
actual schema was checked before recording any migration as applied. Version
`013_blood_color.sql` was genuinely missing and was applied with the owner's
explicit approval. The `bigint NOT NULL` column, ARGB red default and range check
are now present. Restart/refresh the app once so its cached column capabilities
reload, then save the desired color again.

The duplicate `022_replay_global_budget.sql` was byte-identical to canonical
`026_replay_global_budget.sql`. Its original is preserved in
[historical SQL](supabase/historical/022_replay_global_budget.sql), outside the
CLI migration directory. `022_ball_gender.sql` remains version 022.

All 29 canonical versions (001-029) were verified against production, including
columns, RLS, policies, constraints, indexes, function bodies, enabled triggers,
storage bucket limits, sprite API grants and revision backfill. Function bodies
were compared after removing SQL comments and whitespace; constraint and policy
semantics were also reviewed against the inventory. Migration 021's corrected
regex and 020's expanded replay payload constraints supersede older definitions.

Only after verification, the CLI history was repaired as applied for 001-029.
No historical migration SQL was rerun; the only application schema change in
this operation was migration 013. No player records were edited or deleted.

- [Verification evidence](supabase/MIGRATION-BASELINE-VERIFICATION.json)
- [Read-only inventory SQL](../tools/supabase/schema_inventory.sql)
- [Local verification tool](../tools/supabase/verify_inventory.py)

`migration list --remote` confirms all local/remote versions match. A
`db push --remote --include-all --skip-vault --dry-run` reports **Remote database
is up to date**. No config push, reset, seed or vault updates were performed.

## Future migrations

1. Create a uniquely versioned migration after 029 (the CLI can generate timestamp
   names). Never rewrite an already applied migration.
2. Check `npx.cmd --yes supabase migration list --remote`.
3. Preview with `npx.cmd --yes supabase db push --remote --skip-vault --dry-run`.
4. Inspect the exact pending files, then apply the intended migration with
   `npx.cmd --yes supabase db push --remote --skip-vault --yes`.
5. Verify the schema effect and history after application.

If history ever diverges again, inspect actual schema before repairs. Do not
blindly replay old SQL or run `db reset`. The inventory verifier encodes this
specific 001-029 baseline; extend its criteria deliberately for a later baseline.

To reproduce baseline inspection, run `supabase db query --remote --read-only
--file tools/supabase/schema_inventory.sql --output json`, save its JSON to a
local build file, then run `python tools/supabase/verify_inventory.py <input.json>
<report.json>`. These are single-line commands; raw local snapshots belong in
`build/`, not Git. The checked-in evidence contains schema check results and
hashes, not credentials or player data.
