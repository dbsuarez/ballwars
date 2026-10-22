-- Ball Wars: when slow motion starts, set by the admin for everyone
-- (Settings -> SLOW MOTION). Either when one of the last two balls is down to
-- slow_motion_lines lines or fewer (0 turns it off; default 10), or, when
-- slow_motion_before_win is set, that many seconds of game time before the
-- winning cut (the app predicts it by playing the match ahead off-screen).
-- Run once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.
-- Needs 002_admin_and_settings.sql to have been run first.

alter table public.app_settings
  add column if not exists slow_motion_lines integer not null default 10
    check (slow_motion_lines between 0 and 180),
  add column if not exists slow_motion_before_win real
    check (slow_motion_before_win is null or slow_motion_before_win between 0.1 and 10);
