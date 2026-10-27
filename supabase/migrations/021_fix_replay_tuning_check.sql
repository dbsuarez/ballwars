-- Ball Wars: fixes share links for matches with changed power-up numbers.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Migration 011 limited replays.tuning with the pattern {1,2000}, but Postgres only allows repetition
-- counts up to 255, so every insert with a tuning value failed with "invalid regular expression".
-- The same rule, written so Postgres accepts it.
alter table public.replays drop constraint if exists replays_tuning_check;
alter table public.replays add constraint replays_tuning_check check (
  tuning is null or (tuning ~ '^[A-Za-z0-9_-]+$' and char_length(tuning) <= 2000)
);
