-- Q Feed: feed_posts + feed_likes + RLS + trigger'iai
-- Backfill: žr. 20260608000002_feed_posts_backfill.sql

-- 1. Feed posts lentelė
CREATE TABLE IF NOT EXISTS public.feed_posts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_type text NOT NULL CHECK (post_type IN (
    'tournament_match',
    'training_match',
    'external_record',
    'open_match_created',
    'team_created',
    'tournament_joined',
    'tournament_finished'
  )),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  related_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  source_table text,
  source_id uuid,
  sport text,
  location text,
  event_id uuid REFERENCES public.events(id) ON DELETE SET NULL,
  tournament_id uuid REFERENCES public.tournaments(id) ON DELETE SET NULL,
  data jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_feed_posts_source_unique
  ON public.feed_posts (source_table, source_id)
  WHERE source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_feed_posts_created
  ON public.feed_posts (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_posts_user
  ON public.feed_posts (user_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_related
  ON public.feed_posts (related_user_id);
CREATE INDEX IF NOT EXISTS idx_feed_posts_sport
  ON public.feed_posts (sport);

-- 2. Patiktukai
CREATE TABLE IF NOT EXISTS public.feed_likes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL REFERENCES public.feed_posts(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_likes_post
  ON public.feed_likes (post_id);
CREATE INDEX IF NOT EXISTS idx_feed_likes_user
  ON public.feed_likes (user_id);

-- 3. RLS
ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anyone_read_feed" ON public.feed_posts;
CREATE POLICY "anyone_read_feed" ON public.feed_posts
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "system_insert_feed" ON public.feed_posts;
CREATE POLICY "system_insert_feed" ON public.feed_posts
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "anyone_read_likes" ON public.feed_likes;
CREATE POLICY "anyone_read_likes" ON public.feed_likes
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "user_manage_own_likes" ON public.feed_likes;
CREATE POLICY "user_manage_own_likes" ON public.feed_likes
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4. Trigger: matches → feed_posts
CREATE OR REPLACE FUNCTION public.create_feed_post_from_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sport text;
  v_location text;
  v_event_id uuid;
  v_post_type text;
  v_related uuid;
  v_score text;
BEGIN
  IF NEW.status = 'completed'
     AND (OLD IS NULL OR OLD.status IS DISTINCT FROM 'completed')
     AND NEW.winner_id IS NOT NULL THEN

    IF EXISTS (
      SELECT 1 FROM public.feed_posts
      WHERE source_table = 'matches' AND source_id = NEW.id
    ) THEN
      RETURN NEW;
    END IF;

    v_score := COALESCE(NEW.match_details->>'score_str', '');

    IF NEW.tournament_id IS NOT NULL THEN
      SELECT t.event_id, COALESCE(e.sport, t.sport), COALESCE(e.location, NEW.location)
      INTO v_event_id, v_sport, v_location
      FROM public.tournaments t
      LEFT JOIN public.events e ON e.id = t.event_id
      WHERE t.id = NEW.tournament_id;

      v_post_type := 'tournament_match';
    ELSE
      v_post_type := 'training_match';
      v_location := NEW.location;

      SELECT om.sport INTO v_sport
      FROM public.open_matches om
      WHERE om.creator_id IN (NEW.player1_id, NEW.player2_id)
        AND om.match_date::date = COALESCE(NEW.match_date, NEW.created_at)::date
      ORDER BY om.created_at DESC
      LIMIT 1;
    END IF;

    v_related := CASE
      WHEN NEW.winner_id = NEW.player1_id THEN NEW.player2_id
      ELSE NEW.player1_id
    END;

    INSERT INTO public.feed_posts (
      post_type, user_id, related_user_id,
      source_table, source_id, sport, location, event_id, tournament_id, data
    ) VALUES (
      v_post_type,
      NEW.winner_id,
      v_related,
      'matches',
      NEW.id,
      v_sport,
      v_location,
      v_event_id,
      NEW.tournament_id,
      jsonb_build_object(
        'score', v_score,
        'winner_id', NEW.winner_id,
        'player1_id', NEW.player1_id,
        'player2_id', NEW.player2_id
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_feed_from_match ON public.matches;
CREATE TRIGGER trigger_feed_from_match
  AFTER INSERT OR UPDATE OF status ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.create_feed_post_from_match();

-- 5. Trigger: external_records → feed_posts
CREATE OR REPLACE FUNCTION public.create_feed_post_from_external()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.feed_posts
    WHERE source_table = 'external_records' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.feed_posts (
    post_type, user_id, related_user_id,
    source_table, source_id, sport, data
  ) VALUES (
    'external_record',
    NEW.user_id,
    NEW.opponent_user_id,
    'external_records',
    NEW.id,
    NEW.sport,
    jsonb_build_object(
      'opponent_name', NEW.opponent_name,
      'i_won', NEW.i_won,
      'record_type', NEW.record_type,
      'place_taken', NEW.place_taken,
      'tournament_name', NEW.tournament_name
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_feed_from_external ON public.external_records;
CREATE TRIGGER trigger_feed_from_external
  AFTER INSERT ON public.external_records
  FOR EACH ROW
  EXECUTE FUNCTION public.create_feed_post_from_external();

-- 6. Trigger: open_matches → feed_posts
CREATE OR REPLACE FUNCTION public.create_feed_post_from_open_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.feed_posts
    WHERE source_table = 'open_matches' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.feed_posts (
    post_type, user_id, source_table, source_id, sport, location, data
  ) VALUES (
    'open_match_created',
    NEW.creator_id,
    'open_matches',
    NEW.id,
    NEW.sport,
    NEW.location,
    jsonb_build_object(
      'match_date', NEW.match_date,
      'format', NEW.format,
      'level', NEW.level,
      'min_level', NEW.min_level,
      'max_level', NEW.max_level
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_feed_from_open_match ON public.open_matches;
CREATE TRIGGER trigger_feed_from_open_match
  AFTER INSERT ON public.open_matches
  FOR EACH ROW
  EXECUTE FUNCTION public.create_feed_post_from_open_match();

-- 7. Trigger: teams → feed_posts
CREATE OR REPLACE FUNCTION public.create_feed_post_from_team()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.feed_posts
    WHERE source_table = 'teams' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.feed_posts (
    post_type, user_id, source_table, source_id, sport, data
  ) VALUES (
    'team_created',
    NEW.creator_id,
    'teams',
    NEW.id,
    NEW.sport,
    jsonb_build_object('team_name', NEW.name, 'level', NEW.level)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_feed_from_team ON public.teams;
CREATE TRIGGER trigger_feed_from_team
  AFTER INSERT ON public.teams
  FOR EACH ROW
  EXECUTE FUNCTION public.create_feed_post_from_team();

-- 8. Trigger: tournament_participants → feed_posts
CREATE OR REPLACE FUNCTION public.create_feed_post_from_tournament_join()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sport text;
  v_event_id uuid;
  v_t_name text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.feed_posts
    WHERE source_table = 'tournament_participants' AND source_id = NEW.id
  ) THEN
    RETURN NEW;
  END IF;

  SELECT t.event_id, COALESCE(e.sport, t.sport), t.name
  INTO v_event_id, v_sport, v_t_name
  FROM public.tournaments t
  LEFT JOIN public.events e ON e.id = t.event_id
  WHERE t.id = NEW.tournament_id;

  INSERT INTO public.feed_posts (
    post_type, user_id, source_table, source_id, sport, event_id, tournament_id, data
  ) VALUES (
    'tournament_joined',
    NEW.user_id,
    'tournament_participants',
    NEW.id,
    v_sport,
    v_event_id,
    NEW.tournament_id,
    jsonb_build_object('tournament_name', v_t_name)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_feed_from_tournament_join ON public.tournament_participants;
CREATE TRIGGER trigger_feed_from_tournament_join
  AFTER INSERT ON public.tournament_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.create_feed_post_from_tournament_join();
