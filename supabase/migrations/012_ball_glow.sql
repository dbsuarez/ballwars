-- Admin-controlled ball glow. Existing installs and new rows default to on.
alter table public.app_settings
  add column if not exists ball_glow_enabled boolean not null default true;
