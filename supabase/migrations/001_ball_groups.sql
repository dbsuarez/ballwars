-- Ball Wars: user-made ball groups and their images.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Also enable Authentication -> Sign In / Providers -> "Allow anonymous sign-ins".
--
-- Model: every device signs in anonymously and owns the groups it creates.
-- Public groups (the default) can be read by anyone, so shared replay links
-- show their pictures; only the owner can change or delete them.

-- Groups -------------------------------------------------------------------
create table if not exists public.ball_groups (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

-- Balls in a group -----------------------------------------------------------
create table if not exists public.group_balls (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.ball_groups (id) on delete cascade,
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  -- Object path in the ball-images bucket: <owner uid>/<file>
  image_path text check (image_path is null or image_path like (owner::text || '/%')),
  image_style text not null default 'logo' check (image_style in ('logo', 'cover')),
  color text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  position integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists group_balls_group_id_idx on public.group_balls (group_id, position);
create index if not exists ball_groups_owner_idx on public.ball_groups (owner);

-- Keep things small: at most 50 groups per owner and 40 balls per group.
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

drop trigger if exists ball_groups_limit on public.ball_groups;
create trigger ball_groups_limit before insert on public.ball_groups
  for each row execute function public.enforce_ball_limits();
drop trigger if exists group_balls_limit on public.group_balls;
-- Also on moves, so a ball can't be re-pointed into someone else's group.
create trigger group_balls_limit before insert or update of group_id on public.group_balls
  for each row execute function public.enforce_ball_limits();

-- Row level security ---------------------------------------------------------
alter table public.ball_groups enable row level security;
alter table public.group_balls enable row level security;

drop policy if exists "groups readable" on public.ball_groups;
create policy "groups readable" on public.ball_groups for select
  using (is_public or owner = auth.uid());
drop policy if exists "groups owned" on public.ball_groups;
create policy "groups owned" on public.ball_groups for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());

drop policy if exists "balls readable" on public.group_balls;
create policy "balls readable" on public.group_balls for select
  using (exists (select 1 from public.ball_groups g
                 where g.id = group_id and (g.is_public or g.owner = auth.uid())));
drop policy if exists "balls owned" on public.group_balls;
create policy "balls owned" on public.group_balls for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());

-- Image storage --------------------------------------------------------------
-- Public read; 512 KB max; raster images only (no SVG: it can carry scripts).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ball-images', 'ball-images', true, 524288, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Each user writes only inside their own folder: ball-images/<uid>/...
drop policy if exists "ball images upload own" on storage.objects;
create policy "ball images upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'ball-images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "ball images change own" on storage.objects;
create policy "ball images change own" on storage.objects for update to authenticated
  using (bucket_id = 'ball-images' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "ball images delete own" on storage.objects;
create policy "ball images delete own" on storage.objects for delete to authenticated
  using (bucket_id = 'ball-images' and (storage.foldername(name))[1] = auth.uid()::text);
