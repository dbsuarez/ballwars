-- Ball Wars: the Home screen music, picked by the admin for everyone
-- (Settings -> HOME MUSIC; ids: drift, lantern, tide, hearth, starlight).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 002_admin_and_settings.sql to have been run first.

alter table public.app_settings
  add column if not exists menu_music text not null default 'drift'
    check (menu_music ~ '^[a-z0-9-]{1,40}$');
