-- Read-only acceptance queries for an authorized Supabase SQL session.
-- These do not apply migrations or alter any rows, functions or policies.
-- A public REST column probe cannot verify these trigger installations.

-- Supabase displays the final result grid; trigger attachments are last.

-- Check the actual function bodies against migrations 024, 026 and 027.
-- Existence alone does not prove the required lock/budget logic is present.
select p.proname, p.prosecdef as security_definer,
       pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('archive_sprite_revision', 'enforce_replay_global_budget',
                   'lock_ball_wars_limit_insert')
order by p.proname;

with expected(table_name, trigger_name, function_name) as (
  values
    ('sprite_atlases', 'archive_sprite_revision', 'archive_sprite_revision'),
    ('replays', 'enforce_replay_global_budget', 'enforce_replay_global_budget'),
    ('ball_groups', 'a_lock_ball_group_limit', 'lock_ball_wars_limit_insert'),
    ('group_balls', 'a_lock_group_ball_limit', 'lock_ball_wars_limit_insert'),
    ('saved_groups', 'a_lock_saved_group_limit', 'lock_ball_wars_limit_insert')
)
select e.*, t.oid is not null as installed,
       t.tgenabled as enabled_mode, p.proname as installed_function,
       pg_get_triggerdef(t.oid) as trigger_definition
from expected e
left join pg_namespace n on n.nspname = 'public'
left join pg_class c on c.relnamespace = n.oid and c.relname = e.table_name
left join pg_trigger t on t.tgrelid = c.oid and t.tgname = e.trigger_name
                         and not t.tgisinternal
left join pg_proc p on p.oid = t.tgfoid
order by e.table_name, e.trigger_name;
