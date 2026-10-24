alter table public.app_settings
  add column if not exists minimum_arena_scale double precision
  not null default 0.60
  check (minimum_arena_scale between 0.40 and 0.90);
