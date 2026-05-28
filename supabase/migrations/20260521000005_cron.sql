-- =============================================================================
-- QORT: pg_cron – mačų auto-patvirtinimas kas 10 min
-- REIKALAVIMAS: Extensions → pg_cron įjungtas
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Pašaliname seną job jei buvo
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname = 'qort_auto_complete_matches';

-- Kas 10 minučių užbaigia stale played_waiting mačus
SELECT cron.schedule(
  'qort_auto_complete_matches',
  '*/10 * * * *',
  $$SELECT public.auto_complete_stale_matches();$$
);

-- Patikrinimas:
-- SELECT * FROM cron.job WHERE jobname = 'qort_auto_complete_matches';
