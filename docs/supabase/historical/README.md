# Historical migration alias

`022_replay_global_budget.sql` is the original duplicate version alias. It is
byte-identical to canonical `supabase/migrations/026_replay_global_budget.sql`
(SHA-256 `14c03f13b9ee52cc407022a537efbd6f1ec31fabee90985ca5890767896d7b94`).

It is preserved for provenance and must not be run separately. Keeping it outside
`supabase/migrations` eliminates the version collision with `022_ball_gender.sql`.
The production ledger records the replay budget under version 026.
