alter table public.app_settings
  add column if not exists skill_library jsonb not null default '{"version":1,"overrides":{},"custom":[]}'::jsonb;

comment on column public.app_settings.skill_library is
  'Versioned Skill Management definitions, built-in overrides, and custom duplicated skill templates.';
