-- Read-only metadata inventory. No player records, tokens, or stored settings.
select jsonb_build_object(
  'columns', (select jsonb_agg(to_jsonb(c) order by table_name, ordinal_position)
    from information_schema.columns c where table_schema='public'),
  'tables', (select jsonb_agg(jsonb_build_object('name',c.relname,'rls',c.relrowsecurity))
    from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'),
  'constraints', (select jsonb_agg(jsonb_build_object('table',c.conrelid::regclass::text,
    'name',c.conname,'definition',pg_get_constraintdef(c.oid)))
    from pg_constraint c join pg_namespace n on n.oid=c.connamespace where n.nspname='public'),
  'indexes', (select jsonb_agg(to_jsonb(i)) from pg_indexes i where schemaname='public'),
  'policies', (select jsonb_agg(to_jsonb(p)) from pg_policies p
    where schemaname='public' or (schemaname='storage' and tablename='objects')),
  'functions', (select jsonb_agg(jsonb_build_object('name',p.proname,
    'definition',pg_get_functiondef(p.oid),'security_definer',p.prosecdef,'acl',p.proacl))
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind='f'),
  'triggers', (select jsonb_agg(jsonb_build_object('table',t.tgrelid::regclass::text,
    'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)))
    from pg_trigger t join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and not t.tgisinternal),
  'buckets', (select jsonb_agg(jsonb_build_object('id',id,'public',public,
    'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types))
    from storage.buckets where id in ('ball-images','sprite-sheets')),
  'grants', (select jsonb_agg(jsonb_build_object('role',r.name,'table',t.name,
    'privilege',p.name,'allowed',has_table_privilege(r.name,'public.'||t.name,p.name)))
    from (values ('anon'),('authenticated')) r(name)
    cross join (values ('sprite_atlases'),('sprite_atlas_revisions')) t(name)
    cross join (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) p(name)),
  'unarchived_sprite_count', (select count(*) from public.sprite_atlases a
    where not exists (select 1 from public.sprite_atlas_revisions r
      where r.atlas_id=a.id and r.sheet_path=a.sheet_path and r.manifest=a.manifest)),
  'settings_row_present', (select exists(select 1 from public.app_settings where id=1))
) as inventory;
