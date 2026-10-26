alter table public.app_settings
  add column if not exists arena_decoration text not null default 'defaultArena'
  check (arena_decoration in ('defaultArena', 'space', 'desert', 'wilderness', 'neonGrid'));

comment on column public.app_settings.arena_decoration is
  'Visual decoration painted inside the arena; gameplay geometry is unchanged.';
