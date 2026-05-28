-- =============================================================================
-- QORT: RPC funkcijos ir pagalbinės procedūros
-- Paleiskite SQL Editor → Run
-- =============================================================================

-- UUID helper (jei reikia testuose)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- 1. Atominiu būdu pridėti XP (be race condition)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.increment_profile_xp(
  p_user_id uuid,
  p_amount integer
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_xp integer;
BEGIN
  IF p_user_id IS NULL OR p_amount IS NULL OR p_amount = 0 THEN
    RETURN COALESCE((SELECT xp FROM profiles WHERE id = p_user_id), 0);
  END IF;

  UPDATE profiles
  SET xp = COALESCE(xp, 0) + p_amount
  WHERE id = p_user_id
  RETURNING xp INTO v_new_xp;

  RETURN COALESCE(v_new_xp, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_profile_xp(uuid, integer) TO authenticated;

-- -----------------------------------------------------------------------------
-- 2. RP įrašymas į user_sports (turnyrai, atlygiai)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_user_sport_rp(
  p_user_id uuid,
  p_sport text,
  p_earned_rp integer,
  p_event_name text DEFAULT 'Turnyras'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row user_sports%ROWTYPE;
  v_new_rp integer;
  v_history jsonb;
BEGIN
  IF p_user_id IS NULL OR p_sport IS NULL OR p_earned_rp IS NULL OR p_earned_rp = 0 THEN
    RETURN;
  END IF;

  SELECT * INTO v_row
  FROM user_sports
  WHERE user_id = p_user_id AND sport = p_sport
  LIMIT 1;

  IF FOUND THEN
    v_new_rp := COALESCE(v_row.official_rp, 1000) + p_earned_rp;
    v_history := COALESCE(v_row.rp_history, '[]'::jsonb)
      || jsonb_build_array(jsonb_build_object(
        'rp', v_new_rp,
        'date', now()::text,
        'event', p_event_name
      ));

    UPDATE user_sports
    SET official_rp = v_new_rp,
        global_score = v_new_rp,
        rp_history = v_history
    WHERE id = v_row.id;
  ELSE
    v_new_rp := 1000 + p_earned_rp;
    INSERT INTO user_sports (
      user_id, sport, level, official_rp, global_score,
      matches_won, matches_lost, rp_history
    ) VALUES (
      p_user_id, p_sport, 1, v_new_rp, v_new_rp,
      0, 0,
      jsonb_build_array(jsonb_build_object(
        'rp', v_new_rp,
        'date', now()::text,
        'event', p_event_name
      ))
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.award_user_sport_rp(uuid, text, integer, text) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. Ar vartotojas – turnyro savininkas
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_tournament_owner(
  p_tournament_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM tournaments
    WHERE id = p_tournament_id AND owner_id = p_user_id
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_tournament_owner(uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 4. Ar vartotojas – mačo dalyvis
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_match_participant(
  p_match_id uuid,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM matches
    WHERE id = p_match_id
      AND (player1_id = p_user_id OR player2_id = p_user_id)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_match_participant(uuid, uuid) TO authenticated;

-- -----------------------------------------------------------------------------
-- 5. Auto-patvirtinti mačus po 60 min (serverio cron)
-- -----------------------------------------------------------------------------
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
    SELECT id, match_details, updated_at
    FROM matches
    WHERE status = 'played_waiting'
    ORDER BY updated_at ASC
    LIMIT 200
  LOOP
    v_entered_at := NULL;

    IF r.match_details IS NOT NULL
       AND (r.match_details->>'score_entered_at') IS NOT NULL THEN
      v_entered_at := (r.match_details->>'score_entered_at')::timestamptz;
    ELSIF r.updated_at IS NOT NULL THEN
      v_entered_at := r.updated_at;
    END IF;

    IF v_entered_at IS NOT NULL
       AND v_entered_at < (now() - interval '60 minutes') THEN
      UPDATE matches SET status = 'completed' WHERE id = r.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

-- Tik cron / service_role gali masiniu būdu užbaigti
REVOKE ALL ON FUNCTION public.auto_complete_stale_matches() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.auto_complete_stale_matches() TO service_role;

-- -----------------------------------------------------------------------------
-- 6. XP paskirstymas po mačo (kviečiama triggerio)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.distribute_match_xp(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  m matches%ROWTYPE;
  v_is_no_score boolean;
BEGIN
  SELECT * INTO m FROM matches WHERE id = p_match_id;
  IF NOT FOUND OR m.player1_id IS NULL OR m.player2_id IS NULL THEN
    RETURN;
  END IF;

  v_is_no_score := COALESCE((m.match_details->>'is_no_score')::boolean, false);

  IF v_is_no_score THEN
    PERFORM increment_profile_xp(m.player1_id, 10);
    PERFORM increment_profile_xp(m.player2_id, 10);
  ELSIF m.winner_id IS NOT NULL THEN
    PERFORM increment_profile_xp(m.winner_id, 25);
    IF m.winner_id = m.player1_id THEN
      PERFORM increment_profile_xp(m.player2_id, 10);
    ELSE
      PERFORM increment_profile_xp(m.player1_id, 10);
    END IF;
  END IF;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7. Migracija: profiles.my_sports → user_sports (vienkartinis)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.migrate_my_sports_to_user_sports()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  p record;
  s jsonb;
  v_migrated integer := 0;
BEGIN
  FOR p IN
    SELECT id, my_sports
    FROM profiles
    WHERE my_sports IS NOT NULL
      AND jsonb_typeof(my_sports::jsonb) = 'array'
      AND jsonb_array_length(my_sports::jsonb) > 0
  LOOP
    FOR s IN SELECT * FROM jsonb_array_elements(p.my_sports::jsonb)
    LOOP
      IF NOT EXISTS (
        SELECT 1 FROM user_sports
        WHERE user_id = p.id
          AND sport = (s->>'sport')
      ) THEN
        INSERT INTO user_sports (
          user_id, sport, level, description, sport_bio,
          official_rp, global_score, matches_won, matches_lost, rp_history
        ) VALUES (
          p.id,
          s->>'sport',
          COALESCE((s->>'level')::integer, 1),
          COALESCE(s->>'description', ''),
          COALESCE(s->>'sport_bio', ''),
          COALESCE((s->>'official_rp')::integer, 1000),
          COALESCE((s->>'official_rp')::integer, 1000),
          0, 0,
          COALESCE(s->'rp_history', '[]'::jsonb)
        );
        v_migrated := v_migrated + 1;
      END IF;
    END LOOP;
  END LOOP;

  RETURN v_migrated;
END;
$$;

GRANT EXECUTE ON FUNCTION public.migrate_my_sports_to_user_sports() TO authenticated;
