-- Išsaugoti mačų ir dalyvių istoriją trinant turnyrą/event.
-- matches + tournament_participants: CASCADE → SET NULL

-- 1. matches.tournament_id
ALTER TABLE public.matches
  DROP CONSTRAINT IF EXISTS matches_tournament_id_fkey;

ALTER TABLE public.matches
  ALTER COLUMN tournament_id DROP NOT NULL;

ALTER TABLE public.matches
  ADD CONSTRAINT matches_tournament_id_fkey
  FOREIGN KEY (tournament_id)
  REFERENCES public.tournaments(id)
  ON DELETE SET NULL;

-- 2. tournament_participants.tournament_id
ALTER TABLE public.tournament_participants
  DROP CONSTRAINT IF EXISTS tournament_participants_tournament_id_fkey;

ALTER TABLE public.tournament_participants
  ALTER COLUMN tournament_id DROP NOT NULL;

ALTER TABLE public.tournament_participants
  ADD CONSTRAINT tournament_participants_tournament_id_fkey
  FOREIGN KEY (tournament_id)
  REFERENCES public.tournaments(id)
  ON DELETE SET NULL;
