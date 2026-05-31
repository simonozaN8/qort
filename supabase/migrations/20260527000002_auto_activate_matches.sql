-- =============================================================================
-- QORT: Auto-aktyvuoti pending mačus po scheduled_time + 15 min
-- =============================================================================

CREATE OR REPLACE FUNCTION public.auto_activate_scheduled_matches()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.matches
  SET status = 'active'
  WHERE status = 'pending'
    AND scheduled_time IS NOT NULL
    AND scheduled_time < (now() - interval '15 minutes');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_activate_scheduled_matches() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auto_activate_scheduled_matches() TO service_role;

-- pg_cron job (extension jau įjungta 20260521000005_cron.sql)
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'qort_auto_activate_matches';

SELECT cron.schedule(
  'qort_auto_activate_matches',
  '*/5 * * * *',
  $$SELECT public.auto_activate_scheduled_matches();$$
);
