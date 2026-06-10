-- Event status lifecycle: CHECK constraint, indexes, auto-transition function.
-- Cron (pg_cron) paliekamas vėliau — funkciją kvieskite rankiniu būdu:
--   SELECT update_event_lifecycle();

-- 1. CHECK constraint - leidžiamos events.status reikšmės
ALTER TABLE public.events
  DROP CONSTRAINT IF EXISTS events_status_check;

ALTER TABLE public.events
  ADD CONSTRAINT events_status_check
  CHECK (status IN ('open', 'closed', 'in_progress', 'finished', 'cancelled', 'archived'));

-- Legacy: senas 'completed' → 'finished'
UPDATE public.events
SET status = 'finished'
WHERE status = 'completed';

-- 2. tournaments — ta pati būsenų schema (konsistencija su events)
ALTER TABLE public.tournaments
  DROP CONSTRAINT IF EXISTS tournaments_status_check;

ALTER TABLE public.tournaments
  ADD CONSTRAINT tournaments_status_check
  CHECK (status IN ('open', 'closed', 'in_progress', 'finished', 'cancelled', 'archived', 'draft'));

UPDATE public.tournaments
SET status = 'finished'
WHERE status = 'completed';

-- 3. Indeksai - greitam filtravimui
CREATE INDEX IF NOT EXISTS idx_events_status_approval
  ON public.events (status, approval_status);

CREATE INDEX IF NOT EXISTS idx_events_dates
  ON public.events (start_date, end_date);

-- 4. Funkcija - auto-tranzicija pagal datas
CREATE OR REPLACE FUNCTION public.update_event_lifecycle()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- open → in_progress (kai start_date pasiekta)
  UPDATE public.events
  SET status = 'in_progress'
  WHERE status = 'open'
    AND approval_status = 'approved'
    AND start_date IS NOT NULL
    AND start_date <= NOW()
    AND (end_date IS NULL OR end_date > NOW());

  UPDATE public.tournaments t
  SET status = 'in_progress'
  FROM public.events e
  WHERE t.event_id = e.id
    AND e.status = 'in_progress'
    AND t.status = 'open';

  -- open / in_progress → finished (kai end_date praėjo)
  UPDATE public.events
  SET status = 'finished'
  WHERE status IN ('open', 'in_progress')
    AND approval_status = 'approved'
    AND end_date IS NOT NULL
    AND end_date < NOW();

  UPDATE public.tournaments t
  SET status = 'finished'
  FROM public.events e
  WHERE t.event_id = e.id
    AND e.status = 'finished'
    AND t.status IN ('open', 'closed', 'in_progress');
END;
$$;

COMMENT ON FUNCTION public.update_event_lifecycle() IS
  'Auto-tranzicija: open→in_progress (start_date), →finished (end_date). Kviesti rankiniu būdu arba per cron.';

-- 5. pg_cron (vėliau) — patikrinti ar extension prieinamas:
-- SELECT EXISTS (
--   SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron'
-- );
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('update-event-lifecycle', '0 * * * *',
--   'SELECT update_event_lifecycle()');
