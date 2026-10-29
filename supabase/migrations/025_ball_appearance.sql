-- Additive presentation settings; existing app_settings admin RLS applies.
alter table public.app_settings
  add column if not exists ball_appearance jsonb not null default '{}'::jsonb
  check (jsonb_typeof(ball_appearance) = 'object'
    and octet_length(ball_appearance::text) <= 2048);
