-- =============================================================================
-- QORT: Ginčų laukai matches + in-app pranešimai organizatoriui
-- =============================================================================

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS dispute_reason text,
  ADD COLUMN IF NOT EXISTS dispute_created_at timestamptz,
  ADD COLUMN IF NOT EXISTS dispute_by_user_id uuid REFERENCES public.profiles(id);

CREATE TABLE IF NOT EXISTS public.user_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_unread
  ON public.user_notifications (user_id, created_at DESC)
  WHERE read_at IS NULL;

ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_notifications_select_own" ON public.user_notifications;
CREATE POLICY "user_notifications_select_own" ON public.user_notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "user_notifications_update_own" ON public.user_notifications;
CREATE POLICY "user_notifications_update_own" ON public.user_notifications
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Ginčo pateikimas: status + laukai + pranešimas turnyro savininkui
CREATE OR REPLACE FUNCTION public.submit_match_dispute(
  p_match_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  m public.matches%ROWTYPE;
  t_owner uuid;
  v_name text;
  v_body text;
  v_trimmed text;
BEGIN
  v_trimmed := trim(p_reason);
  IF char_length(v_trimmed) < 10 THEN
    RAISE EXCEPTION 'Dispute reason must be at least 10 characters';
  END IF;

  SELECT * INTO m FROM public.matches WHERE id = p_match_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Match not found';
  END IF;

  IF NOT (m.player1_id = auth.uid() OR m.player2_id = auth.uid()) THEN
    RAISE EXCEPTION 'Only match participants can submit a dispute';
  END IF;

  SELECT owner_id INTO t_owner
  FROM public.tournaments
  WHERE id = m.tournament_id;

  IF t_owner IS NULL THEN
    RAISE EXCEPTION 'Tournament owner not found';
  END IF;

  UPDATE public.matches
  SET
    status = 'disputed',
    dispute_reason = v_trimmed,
    dispute_created_at = now(),
    dispute_by_user_id = auth.uid()
  WHERE id = p_match_id;

  SELECT COALESCE(NULLIF(trim(nickname), ''), NULLIF(trim(name), ''), 'Žaidėjas')
  INTO v_name
  FROM public.profiles
  WHERE id = auth.uid();

  v_body := v_name || ': ' || left(v_trimmed, 60);
  IF char_length(v_trimmed) > 60 THEN
    v_body := v_body || '...';
  END IF;

  INSERT INTO public.user_notifications (user_id, type, title, body, payload)
  VALUES (
    t_owner,
    'match_dispute',
    'Naujas ginčas turnyre',
    v_body,
    jsonb_build_object(
      'tournament_id', m.tournament_id,
      'match_id', m.id
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_match_dispute(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_match_dispute(uuid, text) TO authenticated;
