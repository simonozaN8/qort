-- =============================================================================
-- QORT: Indeksai dideliam srautui
-- =============================================================================

-- profiles
CREATE INDEX IF NOT EXISTS idx_profiles_nickname ON public.profiles (nickname);
CREATE INDEX IF NOT EXISTS idx_profiles_xp ON public.profiles (xp DESC);

-- user_sports (reitingai)
CREATE INDEX IF NOT EXISTS idx_user_sports_sport ON public.user_sports (sport);
CREATE INDEX IF NOT EXISTS idx_user_sports_user_id ON public.user_sports (user_id);
CREATE INDEX IF NOT EXISTS idx_user_sports_sport_level ON public.user_sports (sport, level);
CREATE INDEX IF NOT EXISTS idx_user_sports_official_rp ON public.user_sports (sport, official_rp DESC);

-- matches
CREATE INDEX IF NOT EXISTS idx_matches_player1 ON public.matches (player1_id);
CREATE INDEX IF NOT EXISTS idx_matches_player2 ON public.matches (player2_id);
CREATE INDEX IF NOT EXISTS idx_matches_status ON public.matches (status);
CREATE INDEX IF NOT EXISTS idx_matches_tournament ON public.matches (tournament_id);
CREATE INDEX IF NOT EXISTS idx_matches_played_waiting ON public.matches (status, updated_at)
  WHERE status = 'played_waiting';

-- tournaments / events
CREATE INDEX IF NOT EXISTS idx_tournaments_status ON public.tournaments (status);
CREATE INDEX IF NOT EXISTS idx_tournaments_owner ON public.tournaments (owner_id);
CREATE INDEX IF NOT EXISTS idx_events_status ON public.events (status);

-- tournament_participants
CREATE INDEX IF NOT EXISTS idx_tp_tournament ON public.tournament_participants (tournament_id);
CREATE INDEX IF NOT EXISTS idx_tp_user ON public.tournament_participants (user_id);

-- open_matches
CREATE INDEX IF NOT EXISTS idx_open_matches_status ON public.open_matches (status);
CREATE INDEX IF NOT EXISTS idx_open_matches_creator ON public.open_matches (creator_id);

-- chat
CREATE INDEX IF NOT EXISTS idx_direct_messages_chat ON public.direct_messages (chat_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_match_chat_match ON public.match_chat (match_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tournament_chat_tournament ON public.tournament_chat (tournament_id, created_at DESC);

-- teams
CREATE INDEX IF NOT EXISTS idx_team_members_user ON public.team_members (user_id);
CREATE INDEX IF NOT EXISTS idx_team_invitations_invited ON public.team_invitations (invited_user_id, status);

-- external records
CREATE INDEX IF NOT EXISTS idx_external_records_user ON public.external_records (user_id, date_played DESC);
