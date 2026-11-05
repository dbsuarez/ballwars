-- Uses existing app_settings admin RLS and updated_at optimistic concurrency.
alter table public.app_settings add column if not exists arena_catalog jsonb
  not null default '{"version":1,"arenas":[],"default":null}'::jsonb;
do $$ begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.app_settings'::regclass and conname = 'arena_catalog_size') then
    alter table public.app_settings add constraint arena_catalog_size
      check (jsonb_typeof(arena_catalog) = 'object' and octet_length(arena_catalog::text) <= 65536);
  end if;
end $$;
