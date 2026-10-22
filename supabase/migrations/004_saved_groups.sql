-- Ball Wars: groups from other players that a user has added to their own
-- Match Setup categories (through a share link `?g=<group id>`, or the
-- admin's "Everyone's groups" screen).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 001 (and 002 for the admin) to have been run first.
--
-- Groups themselves are already readable by everyone (is_public), so a share
-- link only needs this list; each user sees and changes only their own rows.

create table if not exists public.saved_groups (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  group_id uuid not null references public.ball_groups (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, group_id)
);

create index if not exists saved_groups_group_idx on public.saved_groups (group_id);

alter table public.saved_groups enable row level security;

drop policy if exists "saved groups own" on public.saved_groups;
create policy "saved groups own" on public.saved_groups for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- At most 200 saved groups per user.
create or replace function public.enforce_saved_groups_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from saved_groups where user_id = new.user_id) >= 200 then
    raise exception 'You can add up to 200 groups from other players';
  end if;
  return new;
end $$;

drop trigger if exists saved_groups_limit on public.saved_groups;
create trigger saved_groups_limit before insert on public.saved_groups
  for each row execute function public.enforce_saved_groups_limit();
