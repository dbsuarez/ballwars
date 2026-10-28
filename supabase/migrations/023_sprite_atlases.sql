-- Run in the Supabase SQL Editor. Public art, admin-only mutations.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sprite-sheets', 'sprite-sheets', true, 4194304, array['image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit,
allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.sprite_atlases (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  sheet_path text not null unique check (sheet_path ~ '^[a-f0-9-]+/[a-f0-9-]+\.(png|webp)$'),
  manifest jsonb not null check (jsonb_typeof(manifest) = 'object' and octet_length(manifest::text) <= 262144),
  updated_at timestamptz not null default now()
);
alter table public.sprite_atlases enable row level security;
grant select on public.sprite_atlases to anon, authenticated;
grant insert, update, delete on public.sprite_atlases to authenticated;
create policy "Public sprite manifests" on public.sprite_atlases for select using (true);
create policy "Admins insert sprite manifests" on public.sprite_atlases for insert to authenticated with check (public.is_admin());
create policy "Admins update sprite manifests" on public.sprite_atlases for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins delete sprite manifests" on public.sprite_atlases for delete to authenticated using (public.is_admin());
create policy "Admins upload sprite sheets" on storage.objects for insert to authenticated with check (bucket_id = 'sprite-sheets' and public.is_admin());
create policy "Admins delete sprite sheets" on storage.objects for delete to authenticated using (bucket_id = 'sprite-sheets' and public.is_admin());
