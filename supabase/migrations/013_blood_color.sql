-- Admin-selected blood particle color, stored as an ARGB integer.
alter table public.app_settings
  add column if not exists blood_color bigint not null default 4292416811
    check (blood_color between 0 and 4294967295);
