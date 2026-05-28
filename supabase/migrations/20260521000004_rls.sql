-- =============================================================================
-- QORT: Row Level Security (RLS)
-- Įjungia saugumą – tik autentifikuoti vartotojai su teisėmis
-- =============================================================================

-- Helper: ar prisijungęs
CREATE OR REPLACE FUNCTION public.is_authenticated()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT auth.uid() IS NOT NULL;
$$;

-- =============================================================================
-- PROFILES
-- =============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_authenticated" ON public.profiles;
CREATE POLICY "profiles_select_authenticated" ON public.profiles
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- =============================================================================
-- USER_SPORTS
-- =============================================================================
ALTER TABLE public.user_sports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_sports_select_all" ON public.user_sports;
CREATE POLICY "user_sports_select_all" ON public.user_sports
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "user_sports_insert_own" ON public.user_sports;
CREATE POLICY "user_sports_insert_own" ON public.user_sports
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_sports_update_own" ON public.user_sports;
CREATE POLICY "user_sports_update_own" ON public.user_sports
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "user_sports_delete_own" ON public.user_sports;
CREATE POLICY "user_sports_delete_own" ON public.user_sports
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- =============================================================================
-- SPORTS_CATALOG (tik skaitymas)
-- =============================================================================
ALTER TABLE public.sports_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sports_catalog_select" ON public.sports_catalog;
CREATE POLICY "sports_catalog_select" ON public.sports_catalog
  FOR SELECT TO authenticated
  USING (true);

-- =============================================================================
-- TOURNAMENTS & EVENTS
-- =============================================================================
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tournaments_select" ON public.tournaments;
CREATE POLICY "tournaments_select" ON public.tournaments
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "tournaments_insert_owner" ON public.tournaments;
CREATE POLICY "tournaments_insert_owner" ON public.tournaments
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "tournaments_update_owner" ON public.tournaments;
CREATE POLICY "tournaments_update_owner" ON public.tournaments
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "tournaments_delete_owner" ON public.tournaments;
CREATE POLICY "tournaments_delete_owner" ON public.tournaments
  FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "events_select" ON public.events;
CREATE POLICY "events_select" ON public.events
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "events_insert_owner" ON public.events;
CREATE POLICY "events_insert_owner" ON public.events
  FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "events_update_owner" ON public.events;
CREATE POLICY "events_update_owner" ON public.events
  FOR UPDATE TO authenticated
  USING (owner_id = auth.uid());

-- =============================================================================
-- TOURNAMENT_PARTICIPANTS
-- =============================================================================
ALTER TABLE public.tournament_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tp_select" ON public.tournament_participants;
CREATE POLICY "tp_select" ON public.tournament_participants
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "tp_insert_self" ON public.tournament_participants;
CREATE POLICY "tp_insert_self" ON public.tournament_participants
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "tp_update_owner_or_self" ON public.tournament_participants;
CREATE POLICY "tp_update_owner_or_self" ON public.tournament_participants
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_tournament_owner(tournament_id, auth.uid())
  );

-- =============================================================================
-- MATCHES
-- =============================================================================
ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "matches_select" ON public.matches;
CREATE POLICY "matches_select" ON public.matches
  FOR SELECT TO authenticated
  USING (
    player1_id = auth.uid()
    OR player2_id = auth.uid()
    OR (tournament_id IS NOT NULL AND public.is_tournament_owner(tournament_id, auth.uid()))
    OR tournament_id IS NOT NULL
  );

DROP POLICY IF EXISTS "matches_insert" ON public.matches;
CREATE POLICY "matches_insert" ON public.matches
  FOR INSERT TO authenticated
  WITH CHECK (
    player1_id = auth.uid()
    OR player2_id = auth.uid()
    OR (tournament_id IS NOT NULL AND public.is_tournament_owner(tournament_id, auth.uid()))
  );

DROP POLICY IF EXISTS "matches_update_participant" ON public.matches;
CREATE POLICY "matches_update_participant" ON public.matches
  FOR UPDATE TO authenticated
  USING (
    player1_id = auth.uid()
    OR player2_id = auth.uid()
    OR (tournament_id IS NOT NULL AND public.is_tournament_owner(tournament_id, auth.uid()))
  );

DROP POLICY IF EXISTS "matches_delete_owner" ON public.matches;
CREATE POLICY "matches_delete_owner" ON public.matches
  FOR DELETE TO authenticated
  USING (
    tournament_id IS NOT NULL
    AND public.is_tournament_owner(tournament_id, auth.uid())
  );

-- =============================================================================
-- MATCH_CHAT
-- =============================================================================
ALTER TABLE public.match_chat ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "match_chat_select" ON public.match_chat;
CREATE POLICY "match_chat_select" ON public.match_chat
  FOR SELECT TO authenticated
  USING (public.is_match_participant(match_id, auth.uid()));

DROP POLICY IF EXISTS "match_chat_insert" ON public.match_chat;
CREATE POLICY "match_chat_insert" ON public.match_chat
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_match_participant(match_id, auth.uid())
    AND sender_id = auth.uid()
  );

-- =============================================================================
-- DIRECT CHATS & MESSAGES
-- =============================================================================
ALTER TABLE public.direct_chats ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "direct_chats_select" ON public.direct_chats;
CREATE POLICY "direct_chats_select" ON public.direct_chats
  FOR SELECT TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

DROP POLICY IF EXISTS "direct_chats_insert" ON public.direct_chats;
CREATE POLICY "direct_chats_insert" ON public.direct_chats
  FOR INSERT TO authenticated
  WITH CHECK (user1_id = auth.uid() OR user2_id = auth.uid());

DROP POLICY IF EXISTS "direct_chats_update" ON public.direct_chats;
CREATE POLICY "direct_chats_update" ON public.direct_chats
  FOR UPDATE TO authenticated
  USING (user1_id = auth.uid() OR user2_id = auth.uid());

ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "direct_messages_select" ON public.direct_messages;
CREATE POLICY "direct_messages_select" ON public.direct_messages
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM direct_chats dc
      WHERE dc.id = chat_id
        AND (dc.user1_id = auth.uid() OR dc.user2_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS "direct_messages_insert" ON public.direct_messages;
CREATE POLICY "direct_messages_insert" ON public.direct_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM direct_chats dc
      WHERE dc.id = chat_id
        AND (dc.user1_id = auth.uid() OR dc.user2_id = auth.uid())
    )
  );

-- =============================================================================
-- OPEN_MATCHES
-- =============================================================================
ALTER TABLE public.open_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "open_matches_select" ON public.open_matches;
CREATE POLICY "open_matches_select" ON public.open_matches
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "open_matches_insert" ON public.open_matches;
CREATE POLICY "open_matches_insert" ON public.open_matches
  FOR INSERT TO authenticated
  WITH CHECK (creator_id = auth.uid());

DROP POLICY IF EXISTS "open_matches_update" ON public.open_matches;
CREATE POLICY "open_matches_update" ON public.open_matches
  FOR UPDATE TO authenticated
  USING (creator_id = auth.uid() OR true);

-- =============================================================================
-- TEAMS
-- =============================================================================
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teams_select" ON public.teams;
CREATE POLICY "teams_select" ON public.teams
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "teams_insert" ON public.teams;
CREATE POLICY "teams_insert" ON public.teams
  FOR INSERT TO authenticated
  WITH CHECK (creator_id = auth.uid());

DROP POLICY IF EXISTS "teams_update_creator" ON public.teams;
CREATE POLICY "teams_update_creator" ON public.teams
  FOR UPDATE TO authenticated
  USING (creator_id = auth.uid());

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_members_select" ON public.team_members;
CREATE POLICY "team_members_select" ON public.team_members
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "team_members_insert" ON public.team_members;
CREATE POLICY "team_members_insert" ON public.team_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

ALTER TABLE public.team_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "team_invitations_select" ON public.team_invitations;
CREATE POLICY "team_invitations_select" ON public.team_invitations
  FOR SELECT TO authenticated
  USING (invited_user_id = auth.uid() OR invited_by = auth.uid());

DROP POLICY IF EXISTS "team_invitations_insert" ON public.team_invitations;
CREATE POLICY "team_invitations_insert" ON public.team_invitations
  FOR INSERT TO authenticated
  WITH CHECK (invited_by = auth.uid());

DROP POLICY IF EXISTS "team_invitations_update" ON public.team_invitations;
CREATE POLICY "team_invitations_update" ON public.team_invitations
  FOR UPDATE TO authenticated
  USING (invited_user_id = auth.uid() OR invited_by = auth.uid());

-- =============================================================================
-- EXTERNAL RECORDS, MATCH_SETS, STATS
-- =============================================================================
ALTER TABLE public.external_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "external_records_own" ON public.external_records;
CREATE POLICY "external_records_own" ON public.external_records
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE public.match_sets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "match_sets_via_record" ON public.match_sets;
CREATE POLICY "match_sets_via_record" ON public.match_sets
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM external_records er
      WHERE er.id = record_id AND er.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM external_records er
      WHERE er.id = record_id AND er.user_id = auth.uid()
    )
  );

-- =============================================================================
-- TOURNAMENT CHAT
-- =============================================================================
ALTER TABLE public.tournament_chat ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tournament_chat_select" ON public.tournament_chat;
CREATE POLICY "tournament_chat_select" ON public.tournament_chat
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "tournament_chat_insert" ON public.tournament_chat;
CREATE POLICY "tournament_chat_insert" ON public.tournament_chat
  FOR INSERT TO authenticated
  WITH CHECK (sender_id = auth.uid());
