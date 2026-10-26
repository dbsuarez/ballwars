alter table public.app_settings
  add column if not exists projectile_render_mode text not null default 'sprite'
    check (projectile_render_mode in ('sprite', 'vector')),
  add column if not exists explosion_render_mode text not null default 'sprite'
    check (explosion_render_mode in ('sprite', 'vector')),
  add column if not exists freeze_render_mode text not null default 'sprite'
    check (freeze_render_mode in ('sprite', 'vector'));

comment on column public.app_settings.projectile_render_mode is
  'Admin-selected presentation for projectiles: sprite or vector fallback.';
comment on column public.app_settings.explosion_render_mode is
  'Admin-selected presentation for explosions: sprite or vector fallback.';
comment on column public.app_settings.freeze_render_mode is
  'Admin-selected presentation for freeze shots and impacts: sprite or vector fallback.';
