-- Two admin-controlled lines painted into the arena floor.
alter table public.app_settings
  add column if not exists arena_title text not null default 'dbsuarez'
    check (char_length(arena_title) between 1 and 30),
  add column if not exists arena_subtitle text not null default 'bakbakan na'
    check (char_length(arena_subtitle) between 1 and 50);
