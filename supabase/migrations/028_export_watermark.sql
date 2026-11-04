-- Independent video watermark; preserves existing winner-card branding.
alter table public.app_settings add column if not exists export_watermark_text text not null default 'cha0s'' Balls';
