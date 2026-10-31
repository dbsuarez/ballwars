-- M3: serialize concurrent inserts that existing count-based limit triggers check.
-- Requires earlier migrations defining enforce_ball_limits and
-- enforce_saved_groups_limit. This migration adds locks, not replacement limits.
-- Postgres executes same-kind triggers alphabetically by name, so a_...
-- BEFORE INSERT triggers run before the existing enforce_* triggers.
-- Locks are transaction-scoped, and keyed by the logical counter being capped.

CREATE OR REPLACE FUNCTION public.lock_ball_wars_limit_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  limit_owner text;
  lock_kind text;
BEGIN
  IF TG_TABLE_NAME = 'ball_groups' THEN
    limit_owner := NEW.owner::text;
    lock_kind := 'groups-per-owner';
  ELSIF TG_TABLE_NAME = 'group_balls' THEN
    -- Ball count is capped per group, not per user.
    limit_owner := NEW.group_id::text;
    lock_kind := 'balls-per-group';
  ELSIF TG_TABLE_NAME = 'saved_groups' THEN
    -- Different schema revisions may use owner or user_id. If neither is
    -- stored, the existing saved-group policy scopes inserts to auth.uid().
    limit_owner := coalesce(
      to_jsonb(NEW)->>'owner',
      to_jsonb(NEW)->>'user_id',
      (select auth.uid()::text)
    );
    lock_kind := 'saved-per-owner';
  ELSE
    RAISE EXCEPTION 'Unsupported table for limit lock: %', TG_TABLE_NAME;
  END IF;

  IF limit_owner IS NULL THEN
    RAISE EXCEPTION 'Cannot determine limit owner for %', TG_TABLE_NAME;
  END IF;

  -- Two integer keys avoid lock namespace overlap with other applications.
  -- Hash collisions only serialize extra writers; they cannot bypass limits.
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('ballwars:' || lock_kind),
    pg_catalog.hashtext(limit_owner)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS a_lock_ball_group_limit ON public.ball_groups;
CREATE TRIGGER a_lock_ball_group_limit
BEFORE INSERT ON public.ball_groups
FOR EACH ROW EXECUTE FUNCTION public.lock_ball_wars_limit_insert();

DROP TRIGGER IF EXISTS a_lock_group_ball_limit ON public.group_balls;
CREATE TRIGGER a_lock_group_ball_limit
BEFORE INSERT ON public.group_balls
FOR EACH ROW EXECUTE FUNCTION public.lock_ball_wars_limit_insert();

DROP TRIGGER IF EXISTS a_lock_saved_group_limit ON public.saved_groups;
CREATE TRIGGER a_lock_saved_group_limit
BEFORE INSERT ON public.saved_groups
FOR EACH ROW EXECUTE FUNCTION public.lock_ball_wars_limit_insert();

REVOKE ALL ON FUNCTION public.lock_ball_wars_limit_insert() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.lock_ball_wars_limit_insert() FROM anon, authenticated;
