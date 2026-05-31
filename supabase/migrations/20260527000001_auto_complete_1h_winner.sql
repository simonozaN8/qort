-- =============================================================================
-- QORT: Auto-complete 1h + winner_id (serverio cron atsarginis kelias)
-- =============================================================================

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS completed_at timestamptz;

CREATE OR REPLACE FUNCTION public.auto_complete_stale_matches()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
  r record;
  v_entered_at timestamptz;
BEGIN
  FOR r IN
    SELECT id, score_p1, score_p2, player1_id, player2_id,
           match_details, updated_at, submitted_at
    FROM matches
    WHERE status = 'played_waiting'
    ORDER BY updated_at ASC
    LIMIT 200
  LOOP
    v_entered_at := NULL;

    IF r.match_details IS NOT NULL
       AND (r.match_details->>'score_entered_at') IS NOT NULL THEN
      v_entered_at := (r.match_details->>'score_entered_at')::timestamptz;
    ELSIF r.submitted_at IS NOT NULL THEN
      v_entered_at := r.submitted_at;
    ELSIF r.updated_at IS NOT NULL THEN
      v_entered_at := r.updated_at;
    END IF;

    IF v_entered_at IS NOT NULL
       AND v_entered_at < (now() - interval '1 hour') THEN
      UPDATE matches
      SET
        status = 'completed',
        winner_id = CASE
          WHEN COALESCE(r.score_p1, 0) > COALESCE(r.score_p2, 0) THEN r.player1_id
          WHEN COALESCE(r.score_p2, 0) > COALESCE(r.score_p1, 0) THEN r.player2_id
          ELSE NULL
        END,
        completed_at = now()
      WHERE id = r.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_complete_stale_matches() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auto_complete_stale_matches() TO service_role;
