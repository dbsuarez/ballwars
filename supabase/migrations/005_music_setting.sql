-- Ball Wars: the match music, picked by the admin for everyone
-- (Settings -> MUSIC; ids: arena, turbo, sunny, boss, chill).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 002_admin_and_settings.sql to have been run first.

alter table public.app_settings
  add column if not exists music text not null default 'arena'
    check (music ~ '^[a-z0-9-]{1,40}$');
