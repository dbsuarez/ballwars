-- Run in Supabase SQL Editor before publishing revision-pinned replays.
-- Deleted/replaced library entries retain their immutable public artwork.
begin;
create table if not exists public.sprite_atlas_revisions (
  atlas_id uuid not null,
  revision_id uuid not null,
  name text not null,
  sheet_path text not null unique,
  manifest jsonb not null,
  updated_at timestamptz not null,
  primary key (atlas_id, revision_id)
);
alter table public.sprite_atlas_revisions enable row level security;
revoke all on public.sprite_atlas_revisions from anon, authenticated;
grant select on public.sprite_atlas_revisions to anon, authenticated;
drop policy if exists "Public sprite revisions" on public.sprite_atlas_revisions;
create policy "Public sprite revisions" on public.sprite_atlas_revisions for select using (true);

create or replace function public.archive_sprite_revision() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'UPDATE' and OLD.sheet_path = NEW.sheet_path and OLD.manifest <> NEW.manifest then
    raise exception 'Artwork metadata changes require a new immutable sheet path';
  end if;
  if TG_OP in ('UPDATE', 'DELETE') then
    insert into public.sprite_atlas_revisions
    values (OLD.id, split_part(split_part(OLD.sheet_path,'/',2),'.',1)::uuid,
      OLD.name, OLD.sheet_path, OLD.manifest, OLD.updated_at) on conflict do nothing;
  end if;
  if TG_OP <> 'DELETE' then
    insert into public.sprite_atlas_revisions
    values (NEW.id, split_part(split_part(NEW.sheet_path,'/',2),'.',1)::uuid,
      NEW.name, NEW.sheet_path, NEW.manifest, NEW.updated_at) on conflict do nothing;
    return NEW;
  end if;
  return OLD;
end $$;
revoke all on function public.archive_sprite_revision() from public;
insert into public.sprite_atlas_revisions
select id, split_part(split_part(sheet_path,'/',2),'.',1)::uuid,
  name, sheet_path, manifest, updated_at from public.sprite_atlases on conflict do nothing;
drop trigger if exists archive_sprite_revision on public.sprite_atlases;
create trigger archive_sprite_revision before insert or update or delete on public.sprite_atlases
for each row execute function public.archive_sprite_revision();

-- Restrictive policy also covers older permissive admin storage policies.
drop policy if exists "Retain revision sheets" on storage.objects;
create policy "Retain revision sheets" on storage.objects as restrictive for delete to authenticated
using (bucket_id <> 'sprite-sheets' or not exists (
  select 1 from public.sprite_atlas_revisions r where r.sheet_path = objects.name
));
commit;
