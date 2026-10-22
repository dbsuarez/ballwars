-- Ball Wars: an admin account plus app-wide settings (headline, theme).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Then make yourself admin (see the end of this file).
--
-- Everyone else stays anonymous and is unaffected. The admin (a normal
-- email + password account) may change the app settings and see, edit and
-- delete every user's groups.

-- Admins -------------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.admins enable row level security;
-- No policies: nobody can read or change this table through the API.
-- Add or remove admins here in the SQL editor.

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;

-- App settings (a single row) ---------------------------------------------
create table if not exists public.app_settings (
  id integer primary key default 1 check (id = 1),
  headline text not null default 'WHO WINS?' check (char_length(headline) between 1 and 30),
  theme text not null default 'midnight' check (theme ~ '^[a-z0-9-]{1,40}$'),
  updated_at timestamptz not null default now()
);
insert into public.app_settings (id) values (1) on conflict (id) do nothing;
alter table public.app_settings enable row level security;

drop policy if exists "settings readable" on public.app_settings;
create policy "settings readable" on public.app_settings for select using (true);
drop policy if exists "settings admin" on public.app_settings;
create policy "settings admin" on public.app_settings for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Admin access to every group ------------------------------------------------
drop policy if exists "groups admin" on public.ball_groups;
create policy "groups admin" on public.ball_groups for all to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "balls admin" on public.group_balls;
create policy "balls admin" on public.group_balls for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Let the admin add balls to anyone's group (the ball keeps the group
-- owner's id, so the owner can still edit it).
create or replace function public.enforce_ball_limits() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_table_name = 'ball_groups' then
    if (select count(*) from ball_groups where owner = new.owner) >= 50 then
      raise exception 'Group limit reached (50)';
    end if;
  else
    if (select count(*) from group_balls where group_id = new.group_id) >= 40 then
      raise exception 'Ball limit reached (40 per group)';
    end if;
    if not exists (select 1 from ball_groups where id = new.group_id and owner = new.owner) then
      raise exception 'You can only add balls to your own groups';
    end if;
  end if;
  return new;
end $$;

drop policy if exists "ball images admin" on storage.objects;
create policy "ball images admin" on storage.objects for all to authenticated
  using (bucket_id = 'ball-images' and public.is_admin())
  with check (bucket_id = 'ball-images' and public.is_admin());

-- Make yourself admin --------------------------------------------------------
-- 1. Authentication -> Users -> Add user -> Create new user: your email and a
--    strong password, "Auto Confirm User" ticked.
-- 2. Replace the email below and run just this statement:
--
-- insert into public.admins (user_id)
--   select id from auth.users where email = 'YOUR-EMAIL@example.com'
--   on conflict do nothing;
