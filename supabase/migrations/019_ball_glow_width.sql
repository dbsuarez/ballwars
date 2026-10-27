alter table public.app_settings
  add column if not exists ball_glow_width double precision not null default 4
  check (ball_glow_width between 1 and 12);
