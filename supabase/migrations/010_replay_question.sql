-- Ball Wars: short links remember a Yes or No question (cosmetic; shown as the
-- match headline and answered on the winner card).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 003 (replays) to have been run first.

alter table public.replays
  add column if not exists question text check (question is null or char_length(question) <= 100);
