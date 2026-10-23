-- Ball Wars: ball size in short replay links, and admin balls in the built-in
-- categories.
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 001-003 (and 002 for the admin) to have been run first.

-- Short links remember the match's ball size (xs, s, m, l; m = medium).
alter table public.replays
  add column if not exists size text not null default 'm' check (size in ('xs', 's', 'm', 'l'));

-- A group linked to a built-in category (pack id such as 'streaming'): its
-- balls show up inside that category for everyone (the admin can do this
-- from Everyone's groups with any player's group). Only the admin may link or
-- unlink a group.
alter table public.ball_groups
  add column if not exists pack_id text check (pack_id is null or pack_id ~ '^[a-z0-9-]{1,40}$');

create index if not exists ball_groups_pack_idx on public.ball_groups (pack_id) where pack_id is not null;

create or replace function public.enforce_pack_link_admin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.pack_id is distinct from (case when tg_op = 'INSERT' then null else old.pack_id end)
     and not public.is_admin() then
    raise exception 'Only the admin can add a group to a main category';
  end if;
  return new;
end $$;

drop trigger if exists ball_groups_pack_link on public.ball_groups;
create trigger ball_groups_pack_link before insert or update of pack_id on public.ball_groups
  for each row execute function public.enforce_pack_link_admin();

-- Players can submit their own group for the main categories (set by the
-- group's owner; the admin sees submitted groups first in Everyone's groups).
alter table public.ball_groups
  add column if not exists submitted_at timestamptz;
