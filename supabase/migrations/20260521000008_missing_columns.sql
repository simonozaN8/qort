-- =============================================================================

-- QORT: Trūkstami stulpeliai (terminalo klaidos 42703)

-- Paleiskite SQL Editor → Run (vieną kartą)

-- =============================================================================



-- matches.updated_at (Dashboard rikiavimui, auto-patvirtinimui)

ALTER TABLE public.matches

  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();



UPDATE public.matches

SET updated_at = COALESCE(created_at, now())

WHERE updated_at IS NULL;



-- user_sports.rp_history (reitingų istorija)

ALTER TABLE public.user_sports

  ADD COLUMN IF NOT EXISTS rp_history jsonb DEFAULT '[]'::jsonb;



UPDATE public.user_sports

SET rp_history = '[]'::jsonb

WHERE rp_history IS NULL;



-- Indeksas (jei dar nebuvo – reikia updated_at)

CREATE INDEX IF NOT EXISTS idx_matches_played_waiting

  ON public.matches (status, updated_at)

  WHERE status = 'played_waiting';



-- Triggeris: updated_at atnaujinamas keičiant mačą

CREATE OR REPLACE FUNCTION public.set_updated_at()

RETURNS trigger

LANGUAGE plpgsql

AS $$

BEGIN

  NEW.updated_at = now();

  RETURN NEW;

END;

$$;



DROP TRIGGER IF EXISTS set_matches_updated_at ON public.matches;

CREATE TRIGGER set_matches_updated_at

  BEFORE UPDATE ON public.matches

  FOR EACH ROW

  EXECUTE FUNCTION public.set_updated_at();


