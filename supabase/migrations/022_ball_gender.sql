-- Ball Wars: a gender for group balls (picked in the ball editor), so male and female balls wear
-- hair from their own style pool. Cosmetic only.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- Until this has run, the app reads every ball as 'none' and saves balls without a gender.
alter table public.group_balls add column if not exists gender text not null default 'none'
  check (gender in ('none', 'male', 'female'));
