-- Ball Wars: the admin's power-up numbers (Settings -> POWER-UPS) and the numbers a shared
-- replay was played with.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 002_admin_and_settings.sql and 003_short_links_and_watermark.sql to have been run first.

-- Only the values the admin changed, by field id (see PowerUpConfig.fields), e.g. {"dmg.pistol": 15}.
-- Empty means every default. The existing app_settings policies let only the admin write it.
alter table public.app_settings
  add column if not exists power_ups jsonb not null default '{}'::jsonb
    check (jsonb_typeof(power_ups) = 'object' and length(power_ups::text) <= 4000);

-- Short links keep the changed numbers the match used (the link's t= value: base64url JSON).
alter table public.replays
  add column if not exists tuning text check (
    tuning is null or (tuning ~ '^[A-Za-z0-9_-]+$' and char_length(tuning) <= 2000)
  );
-- (Originally written as {1,2000}, which Postgres rejects at insert time; see migration 021.)
