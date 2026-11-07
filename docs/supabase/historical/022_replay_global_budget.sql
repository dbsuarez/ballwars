-- Ball Wars H1: cap public replay creation across ALL anonymous identities.
-- Run after migrations 007 and 020 in the Supabase SQL editor.
-- This protects the shared database quota from unlimited anonymous account rotation.
-- Limits are deliberately project-wide; reaching them temporarily disables new links,
-- but existing links remain readable. Tune values for actual usage.
-- Requires public.replays(created_at, replay_payload). Does not delete existing rows.

CREATE OR REPLACE FUNCTION public.enforce_replay_global_budget()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  day_start timestamptz := date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC';
  daily_count bigint;
  daily_bytes bigint;
  incoming_bytes bigint := octet_length(coalesce(NEW.replay_payload::text, ''));
  max_daily_replays constant bigint := 2000;
  max_daily_bytes constant bigint := 104857600; -- 100 MiB
  max_replay_bytes constant bigint := 524288; -- same as ReplayDocument.maxBytes
BEGIN
  IF incoming_bytes > max_replay_bytes THEN
    RAISE EXCEPTION 'Replay exceeds the maximum size' USING ERRCODE = 'P0001';
  END IF;

  -- Serialize writers across all accounts so concurrent inserts cannot race
  -- past the project-wide quota. This lock is held only for the transaction.
  PERFORM pg_catalog.pg_advisory_xact_lock(726199, 22);
  SELECT count(*), coalesce(sum(octet_length(coalesce(r.replay_payload::text, ''))), 0)
    INTO daily_count, daily_bytes
    FROM public.replays AS r
   WHERE r.created_at >= day_start;

  IF daily_count >= max_daily_replays OR
     daily_bytes + incoming_bytes > max_daily_bytes THEN
    RAISE EXCEPTION 'Daily replay sharing limit reached; try again tomorrow'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_replay_global_budget ON public.replays;
CREATE TRIGGER enforce_replay_global_budget
BEFORE INSERT ON public.replays
FOR EACH ROW EXECUTE FUNCTION public.enforce_replay_global_budget();

-- The SECURITY DEFINER function is a trigger, not a callable public API.
REVOKE ALL ON FUNCTION public.enforce_replay_global_budget() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_replay_global_budget() FROM anon, authenticated;

-- Helps the daily budget query as replay history grows.
CREATE INDEX IF NOT EXISTS replays_created_at_global_budget_idx
  ON public.replays (created_at);
