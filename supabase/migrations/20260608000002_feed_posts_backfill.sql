-- Q Feed backfill: esami duomenys → feed_posts
-- Paleisti PO 20260608000001_feed_posts.sql
-- Praleidžia orphan įrašus (user'iai be profiles eilutės)

-- Baigti turnyriniai mačai
INSERT INTO public.feed_posts (
  post_type, user_id, related_user_id, source_table, source_id,
  sport, location, event_id, tournament_id, data, created_at
)
SELECT
  'tournament_match',
  m.winner_id,
  CASE WHEN m.winner_id = m.player1_id THEN m.player2_id ELSE m.player1_id END,
  'matches',
  m.id,
  COALESCE(e.sport, t.sport),
  COALESCE(e.location, m.location),
  t.event_id,
  m.tournament_id,
  jsonb_build_object(
    'score', COALESCE(m.match_details->>'score_str', ''),
    'winner_id', m.winner_id,
    'player1_id', m.player1_id,
    'player2_id', m.player2_id
  ),
  COALESCE(m.updated_at, m.created_at, now())
FROM public.matches m
JOIN public.tournaments t ON t.id = m.tournament_id
LEFT JOIN public.events e ON e.id = t.event_id
WHERE m.status = 'completed'
  AND m.winner_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.winner_id)
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.player1_id)
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.player2_id)
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'matches' AND fp.source_id = m.id
  );

-- Treniruotės mačai (be turnyro)
INSERT INTO public.feed_posts (
  post_type, user_id, related_user_id, source_table, source_id,
  sport, location, data, created_at
)
SELECT
  'training_match',
  m.winner_id,
  CASE WHEN m.winner_id = m.player1_id THEN m.player2_id ELSE m.player1_id END,
  'matches',
  m.id,
  om.sport,
  m.location,
  jsonb_build_object(
    'score', COALESCE(m.match_details->>'score_str', ''),
    'winner_id', m.winner_id,
    'player1_id', m.player1_id,
    'player2_id', m.player2_id
  ),
  COALESCE(m.updated_at, m.created_at, now())
FROM public.matches m
LEFT JOIN LATERAL (
  SELECT om.sport
  FROM public.open_matches om
  WHERE om.creator_id IN (m.player1_id, m.player2_id)
    AND om.match_date::date = COALESCE(m.match_date, m.created_at)::date
  ORDER BY om.created_at DESC
  LIMIT 1
) om ON true
WHERE m.status = 'completed'
  AND m.tournament_id IS NULL
  AND m.winner_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.winner_id)
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.player1_id)
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = m.player2_id)
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'matches' AND fp.source_id = m.id
  );

-- Išoriniai įrašai
INSERT INTO public.feed_posts (
  post_type, user_id, related_user_id, source_table, source_id, sport, data, created_at
)
SELECT
  'external_record',
  er.user_id,
  er.opponent_user_id,
  'external_records',
  er.id,
  er.sport,
  jsonb_build_object(
    'opponent_name', er.opponent_name,
    'i_won', er.i_won,
    'record_type', er.record_type,
    'place_taken', er.place_taken,
    'tournament_name', er.tournament_name
  ),
  COALESCE(er.date_played::timestamptz, er.created_at, now())
FROM public.external_records er
WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = er.user_id)
  AND (
    er.opponent_user_id IS NULL
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = er.opponent_user_id)
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'external_records' AND fp.source_id = er.id
  );

-- Atviri mačai
INSERT INTO public.feed_posts (
  post_type, user_id, source_table, source_id, sport, location, data, created_at
)
SELECT
  'open_match_created',
  om.creator_id,
  'open_matches',
  om.id,
  om.sport,
  om.location,
  jsonb_build_object(
    'match_date', om.match_date,
    'format', om.format,
    'level', om.level,
    'min_level', om.min_level,
    'max_level', om.max_level
  ),
  COALESCE(om.created_at, now())
FROM public.open_matches om
WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = om.creator_id)
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'open_matches' AND fp.source_id = om.id
  );

-- Komandos
INSERT INTO public.feed_posts (
  post_type, user_id, source_table, source_id, sport, data, created_at
)
SELECT
  'team_created',
  t.creator_id,
  'teams',
  t.id,
  t.sport,
  jsonb_build_object('team_name', t.name, 'level', t.level),
  COALESCE(t.created_at, now())
FROM public.teams t
WHERE t.creator_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM public.profiles WHERE id = t.creator_id)
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'teams' AND fp.source_id = t.id
  );

-- Turnyro registracijos
INSERT INTO public.feed_posts (
  post_type, user_id, source_table, source_id, sport, event_id, tournament_id, data, created_at
)
SELECT
  'tournament_joined',
  tp.user_id,
  'tournament_participants',
  tp.id,
  COALESCE(e.sport, t.sport),
  t.event_id,
  tp.tournament_id,
  jsonb_build_object('tournament_name', t.name),
  COALESCE(tp.created_at, now())
FROM public.tournament_participants tp
JOIN public.tournaments t ON t.id = tp.tournament_id
LEFT JOIN public.events e ON e.id = t.event_id
WHERE EXISTS (SELECT 1 FROM public.profiles WHERE id = tp.user_id)
  AND NOT EXISTS (
    SELECT 1 FROM public.feed_posts fp
    WHERE fp.source_table = 'tournament_participants' AND fp.source_id = tp.id
  );
