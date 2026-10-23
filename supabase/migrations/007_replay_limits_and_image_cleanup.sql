-- Ball Wars: abuse limits for short replay links, and finding ball images
-- that no ball uses any more (left behind when a delete's storage cleanup
-- failed).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 002 (admin) and 003 (replays) to have been run first.

-- Replays: who made each link; only signed-in users (every device has an
-- anonymous account) may create links, at most 200 per day each. Links never
-- expire: deleting them would break links people already shared.
alter table public.replays
  add column if not exists creator uuid default auth.uid() references auth.users (id) on delete set null;

create index if not exists replays_creator_idx on public.replays (creator, created_at);

drop policy if exists "replays insert" on public.replays;
create policy "replays insert" on public.replays for insert to authenticated
  with check (creator = auth.uid());

create or replace function public.enforce_replay_limit() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from replays
      where creator = new.creator and created_at > now() - interval '1 day') >= 200 then
    raise exception 'Too many share links today, try again tomorrow';
  end if;
  return new;
end $$;

drop trigger if exists replays_limit on public.replays;
create trigger replays_limit before insert on public.replays
  for each row execute function public.enforce_replay_limit();

-- Unused ball images: files in the ball-images bucket that no group ball
-- points to, older than a day (so an upload in progress is never listed).
-- Admin only; the app then deletes them through the Storage API (Settings ->
-- Clean up unused images), since storage files can't be deleted from SQL.
create or replace function public.orphan_ball_images() returns setof text
language plpgsql stable security definer set search_path = public, storage as $$
begin
  if not public.is_admin() then
    raise exception 'Only the admin can list unused images';
  end if;
  return query
    select o.name from storage.objects o
    where o.bucket_id = 'ball-images'
      and o.created_at < now() - interval '1 day'
      and not exists (select 1 from public.group_balls b where b.image_path = o.name);
end $$;

revoke all on function public.orphan_ball_images() from public, anon;
grant execute on function public.orphan_ball_images() to authenticated;
