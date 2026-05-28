-- =============================================================================
-- QORT: komandų / porų registracija į turnyrus (2v2, 3x3, …)
-- Paleiskite SQL Editor → Run (vieną kartą)
-- =============================================================================

ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS format_code text,
  ADD COLUMN IF NOT EXISTS team_format text,
  ADD COLUMN IF NOT EXISTS min_roster_size integer DEFAULT 1;

ALTER TABLE public.tournament_participants
  ADD COLUMN IF NOT EXISTS team_id uuid REFERENCES public.teams (id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tp_team_id
  ON public.tournament_participants (team_id)
  WHERE team_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tp_tournament_team
  ON public.tournament_participants (tournament_id, team_id)
  WHERE team_id IS NOT NULL;

COMMENT ON COLUMN public.tournament_participants.team_id IS
  'QORT komanda (pora / komanda). Vienas įrašas = viena starto vieta turnyre.';
