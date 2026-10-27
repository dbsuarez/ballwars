-- Run in the Supabase SQL Editor. Existing short links remain valid.
-- Full, versioned .bw JSON replay documents preserve every match option.
alter table public.replays add column if not exists replay_payload jsonb;

alter table public.replays drop constraint if exists replays_payload_check;
alter table public.replays add constraint replays_payload_check check (
  replay_payload is null or (
    jsonb_typeof(replay_payload) = 'object'
    and replay_payload ?& array['format', 'version', 'query']
    and replay_payload ->> 'format' = 'ballwars-replay'
    and replay_payload ->> 'version' = '1'
    and jsonb_typeof(replay_payload -> 'query') = 'object'
    and octet_length(replay_payload::text) <= 1048576
  )
);

alter table public.replays drop constraint if exists replays_balls_check;
alter table public.replays add constraint replays_balls_check
  check (char_length(balls) between 3 and 524288);
