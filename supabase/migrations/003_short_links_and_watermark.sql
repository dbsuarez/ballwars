-- Ball Wars: short share links (https://dbsuarez.github.io/ballwars/?r=aB3x9Kq) and the
-- winner-card watermark setting.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
--
-- A shared match is stored under a random 7-character code. Long links
-- (?seed=..&balls=..) can be cut off by chat apps such as Messenger; the
-- short one can't. Anyone may create or read a replay; nobody can change or
-- delete one through the app.

create table if not exists public.replays (
  id text primary key check (id ~ '^[A-Za-z0-9]{7}$'),
  seed bigint not null,
  speed real not null default 1 check (speed > 0 and speed <= 8),
  effects boolean not null default true,
  -- The ball tokens of the long link, comma-separated (p./k./g./c. tokens).
  balls text not null check (char_length(balls) between 3 and 2000),
  created_at timestamptz not null default now()
);

alter table public.replays enable row level security;

drop policy if exists "replays readable" on public.replays;
create policy "replays readable" on public.replays for select using (true);

drop policy if exists "replays insert" on public.replays;
create policy "replays insert" on public.replays for insert to anon, authenticated with check (true);

-- Winner-card watermark (admin setting) -------------------------------------
-- Needs 002_admin_and_settings.sql to have been run first.
alter table public.app_settings
  add column if not exists watermark_enabled boolean not null default true,
  add column if not exists watermark_text text not null default 'dbsuarez'
    check (char_length(watermark_text) between 1 and 30);
