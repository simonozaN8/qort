-- QORT: įjungti RLS ir policies lentelėms be saugumo.
-- Idempotentiška: DROP POLICY IF EXISTS prieš CREATE.
-- Pastaba: match_player_stats prod — match_id + user_id; match_sets — record_id.
-- Blitz lobbies — savininkas gali būti creator_id, host_id, user_id ir kt.

-- ===========================================
-- 1. ASMENINIAI POKALBIAI - tik dalyviai
-- ===========================================

ALTER TABLE public.direct_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "direct_chats_select" ON public.direct_chats;
DROP POLICY IF EXISTS "direct_chats_insert" ON public.direct_chats;
DROP POLICY IF EXISTS "direct_chats_update" ON public.direct_chats;
DROP POLICY IF EXISTS "user_view_own_chats" ON public.direct_chats;
DROP POLICY IF EXISTS "user_create_own_chats" ON public.direct_chats;

CREATE POLICY "user_view_own_chats" ON public.direct_chats
  FOR SELECT TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "user_create_own_chats" ON public.direct_chats
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user1_id OR auth.uid() = user2_id);

CREATE POLICY "user_update_own_chats" ON public.direct_chats
  FOR UPDATE TO authenticated
  USING (auth.uid() = user1_id OR auth.uid() = user2_id);

DROP POLICY IF EXISTS "direct_messages_select" ON public.direct_messages;
DROP POLICY IF EXISTS "direct_messages_insert" ON public.direct_messages;
DROP POLICY IF EXISTS "user_view_chat_messages" ON public.direct_messages;
DROP POLICY IF EXISTS "user_send_messages" ON public.direct_messages;

CREATE POLICY "user_view_chat_messages" ON public.direct_messages
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.direct_chats dc
    WHERE dc.id = chat_id
      AND (dc.user1_id = auth.uid() OR dc.user2_id = auth.uid())
  ));

CREATE POLICY "user_send_messages" ON public.direct_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.direct_chats dc
      WHERE dc.id = chat_id
        AND (dc.user1_id = auth.uid() OR dc.user2_id = auth.uid())
    )
  );

-- ===========================================
-- 2. USER_SPORTS - tik savininkas redaguoja
-- ===========================================

ALTER TABLE public.user_sports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_sports_select_all" ON public.user_sports;
DROP POLICY IF EXISTS "user_sports_insert_own" ON public.user_sports;
DROP POLICY IF EXISTS "user_sports_update_own" ON public.user_sports;
DROP POLICY IF EXISTS "user_sports_delete_own" ON public.user_sports;
DROP POLICY IF EXISTS "anyone_view_user_sports" ON public.user_sports;
DROP POLICY IF EXISTS "user_manage_own_sports" ON public.user_sports;

CREATE POLICY "anyone_view_user_sports" ON public.user_sports
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "user_manage_own_sports" ON public.user_sports
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- ===========================================
-- 3. EXTERNAL_RECORDS - viešas skaitymas, savininkas valdo
-- ===========================================

ALTER TABLE public.external_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "external_records_own" ON public.external_records;
DROP POLICY IF EXISTS "anyone_view_external_records" ON public.external_records;
DROP POLICY IF EXISTS "user_manage_own_external" ON public.external_records;

CREATE POLICY "anyone_view_external_records" ON public.external_records
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "user_manage_own_external" ON public.external_records
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_update_own_external" ON public.external_records
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_delete_own_external" ON public.external_records
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

-- ===========================================
-- 4. MATCH_SETS, MATCH_PLAYER_STATS - per external_records savininką
-- ===========================================

DO $$
DECLARE
  v_fk_col text;
  v_sql text;
  v_using_parts text[] := ARRAY[]::text[];
  v_check_parts text[] := ARRAY[]::text[];
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'match_sets'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'match_sets'
      AND column_name = 'record_id'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'match_sets'
        AND column_name = 'external_record_id'
    ) THEN
      ALTER TABLE public.match_sets
        RENAME COLUMN external_record_id TO record_id;
    ELSE
      ALTER TABLE public.match_sets
        ADD COLUMN record_id uuid REFERENCES public.external_records(id) ON DELETE CASCADE;
    END IF;
  END IF;

  -- match_sets
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'match_sets'
  ) THEN
    ALTER TABLE public.match_sets ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "match_sets_via_record" ON public.match_sets;
    DROP POLICY IF EXISTS "anyone_view_match_sets" ON public.match_sets;
    DROP POLICY IF EXISTS "owner_manage_match_sets" ON public.match_sets;
    DROP POLICY IF EXISTS "players_manage_match_sets" ON public.match_sets;

    CREATE POLICY "anyone_view_match_sets" ON public.match_sets
      FOR SELECT TO authenticated USING (true);

    SELECT column_name INTO v_fk_col
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'match_sets'
      AND column_name IN ('record_id', 'external_record_id')
    ORDER BY CASE column_name WHEN 'record_id' THEN 1 ELSE 2 END
    LIMIT 1;

    IF v_fk_col IS NOT NULL THEN
      v_sql := format(
        'CREATE POLICY owner_manage_match_sets ON public.match_sets
           FOR ALL TO authenticated
           USING (EXISTS (
             SELECT 1 FROM public.external_records er
             WHERE er.id = %I AND er.user_id = auth.uid()
           ))
           WITH CHECK (EXISTS (
             SELECT 1 FROM public.external_records er
             WHERE er.id = %I AND er.user_id = auth.uid()
           ))',
        v_fk_col, v_fk_col
      );
      EXECUTE v_sql;
    END IF;
  END IF;

  -- match_player_stats
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'match_player_stats'
  ) THEN
    ALTER TABLE public.match_player_stats ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_view_player_stats" ON public.match_player_stats;
    DROP POLICY IF EXISTS "players_manage_player_stats" ON public.match_player_stats;
    DROP POLICY IF EXISTS "owner_manage_player_stats" ON public.match_player_stats;
    DROP POLICY IF EXISTS "user_manage_player_stats" ON public.match_player_stats;

    CREATE POLICY "anyone_view_player_stats" ON public.match_player_stats
      FOR SELECT TO authenticated USING (true);

    v_using_parts := ARRAY[]::text[];
    v_check_parts := ARRAY[]::text[];

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'match_player_stats'
        AND column_name = 'user_id'
    ) THEN
      v_using_parts := array_append(v_using_parts, 'user_id = auth.uid()');
      v_check_parts := array_append(v_check_parts, 'user_id = auth.uid()');
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'match_player_stats'
        AND column_name = 'player_id'
    ) THEN
      v_using_parts := array_append(v_using_parts, 'player_id = auth.uid()');
      v_check_parts := array_append(v_check_parts, 'player_id = auth.uid()');
    END IF;

    FOR v_fk_col IN
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'match_player_stats'
        AND column_name IN ('record_id', 'external_record_id', 'match_id')
      ORDER BY CASE column_name
        WHEN 'record_id' THEN 1
        WHEN 'external_record_id' THEN 2
        ELSE 3
      END
    LOOP
      v_using_parts := array_append(
        v_using_parts,
        format(
          'EXISTS (SELECT 1 FROM public.external_records er WHERE er.id = %I AND er.user_id = auth.uid())',
          v_fk_col
        )
      );
      v_check_parts := array_append(
        v_check_parts,
        format(
          'EXISTS (SELECT 1 FROM public.external_records er WHERE er.id = %I AND er.user_id = auth.uid())',
          v_fk_col
        )
      );
    END LOOP;

    IF array_length(v_using_parts, 1) IS NOT NULL THEN
      v_sql := format(
        'CREATE POLICY user_manage_player_stats ON public.match_player_stats
           FOR ALL TO authenticated
           USING (%s)
           WITH CHECK (%s)',
        array_to_string(v_using_parts, ' OR '),
        array_to_string(v_check_parts, ' OR ')
      );
      EXECUTE v_sql;
    END IF;
  END IF;
END $$;

-- ===========================================
-- 5. RANKING_HISTORY - tik skaitymas
-- ===========================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'ranking_history'
  ) THEN
    ALTER TABLE public.ranking_history ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_view_rankings" ON public.ranking_history;

    CREATE POLICY "anyone_view_rankings" ON public.ranking_history
      FOR SELECT TO authenticated USING (true);
  END IF;
END $$;

-- ===========================================
-- 6. KOMANDOS - viešas skaitymas, narių valdymas
-- ===========================================

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_invitations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teams_select" ON public.teams;
DROP POLICY IF EXISTS "teams_insert" ON public.teams;
DROP POLICY IF EXISTS "teams_update_creator" ON public.teams;
DROP POLICY IF EXISTS "anyone_view_teams" ON public.teams;
DROP POLICY IF EXISTS "user_create_team" ON public.teams;
DROP POLICY IF EXISTS "creator_manage_team" ON public.teams;
DROP POLICY IF EXISTS "creator_delete_team" ON public.teams;

CREATE POLICY "anyone_view_teams" ON public.teams
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "user_create_team" ON public.teams
  FOR INSERT TO authenticated
  WITH CHECK (creator_id = auth.uid());

CREATE POLICY "creator_manage_team" ON public.teams
  FOR UPDATE TO authenticated
  USING (creator_id = auth.uid());

CREATE POLICY "creator_delete_team" ON public.teams
  FOR DELETE TO authenticated
  USING (creator_id = auth.uid());

DROP POLICY IF EXISTS "team_members_select" ON public.team_members;
DROP POLICY IF EXISTS "team_members_insert" ON public.team_members;
DROP POLICY IF EXISTS "anyone_view_team_members" ON public.team_members;
DROP POLICY IF EXISTS "creator_manage_members" ON public.team_members;
DROP POLICY IF EXISTS "user_join_team" ON public.team_members;
DROP POLICY IF EXISTS "user_leave_team" ON public.team_members;

CREATE POLICY "anyone_view_team_members" ON public.team_members
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "user_join_team" ON public.team_members
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "creator_manage_members" ON public.team_members
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.teams t
    WHERE t.id = team_id AND t.creator_id = auth.uid()
  ));

CREATE POLICY "user_leave_team" ON public.team_members
  FOR DELETE TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "team_invitations_select" ON public.team_invitations;
DROP POLICY IF EXISTS "team_invitations_insert" ON public.team_invitations;
DROP POLICY IF EXISTS "team_invitations_update" ON public.team_invitations;
DROP POLICY IF EXISTS "view_team_invitations" ON public.team_invitations;
DROP POLICY IF EXISTS "send_team_invitations" ON public.team_invitations;
DROP POLICY IF EXISTS "respond_team_invitations" ON public.team_invitations;

CREATE POLICY "view_team_invitations" ON public.team_invitations
  FOR SELECT TO authenticated
  USING (invited_user_id = auth.uid() OR invited_by = auth.uid());

CREATE POLICY "send_team_invitations" ON public.team_invitations
  FOR INSERT TO authenticated
  WITH CHECK (invited_by = auth.uid());

CREATE POLICY "respond_team_invitations" ON public.team_invitations
  FOR UPDATE TO authenticated
  USING (invited_user_id = auth.uid() OR invited_by = auth.uid());

-- ===========================================
-- 7. OPEN_MATCHES - viešas skaitymas, kūrėjas valdo
-- ===========================================

ALTER TABLE public.open_matches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "open_matches_select" ON public.open_matches;
DROP POLICY IF EXISTS "open_matches_insert" ON public.open_matches;
DROP POLICY IF EXISTS "open_matches_update" ON public.open_matches;
DROP POLICY IF EXISTS "anyone_view_open_matches" ON public.open_matches;
DROP POLICY IF EXISTS "user_create_open_match" ON public.open_matches;
DROP POLICY IF EXISTS "creator_manage_open_match" ON public.open_matches;
DROP POLICY IF EXISTS "creator_delete_open_match" ON public.open_matches;

CREATE POLICY "anyone_view_open_matches" ON public.open_matches
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "user_create_open_match" ON public.open_matches
  FOR INSERT TO authenticated
  WITH CHECK (creator_id = auth.uid());

CREATE POLICY "creator_manage_open_match" ON public.open_matches
  FOR UPDATE TO authenticated
  USING (creator_id = auth.uid());

CREATE POLICY "creator_delete_open_match" ON public.open_matches
  FOR DELETE TO authenticated
  USING (creator_id = auth.uid());

-- ===========================================
-- 8. BLITZ - viešas skaitymas, kūrėjas valdo
-- ===========================================

DO $$
DECLARE
  v_owner_col text;
  v_member_col text;
  v_sql text;
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'blitz_lobbies'
  ) THEN
    ALTER TABLE public.blitz_lobbies ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_view_blitz_lobbies" ON public.blitz_lobbies;
    DROP POLICY IF EXISTS "user_create_blitz_lobby" ON public.blitz_lobbies;
    DROP POLICY IF EXISTS "creator_manage_blitz_lobby" ON public.blitz_lobbies;
    DROP POLICY IF EXISTS "host_manage_blitz_lobby" ON public.blitz_lobbies;

    CREATE POLICY "anyone_view_blitz_lobbies" ON public.blitz_lobbies
      FOR SELECT TO authenticated USING (true);

    SELECT column_name INTO v_owner_col
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'blitz_lobbies'
      AND column_name IN ('creator_id', 'host_id', 'user_id', 'owner_id', 'created_by')
    ORDER BY CASE column_name
      WHEN 'creator_id' THEN 1
      WHEN 'host_id' THEN 2
      WHEN 'user_id' THEN 3
      WHEN 'owner_id' THEN 4
      ELSE 5
    END
    LIMIT 1;

    IF v_owner_col IS NOT NULL THEN
      v_sql := format(
        'CREATE POLICY user_create_blitz_lobby ON public.blitz_lobbies
           FOR INSERT TO authenticated
           WITH CHECK (%I = auth.uid())',
        v_owner_col
      );
      EXECUTE v_sql;

      v_sql := format(
        'CREATE POLICY creator_manage_blitz_lobby ON public.blitz_lobbies
           FOR UPDATE TO authenticated
           USING (%I = auth.uid())',
        v_owner_col
      );
      EXECUTE v_sql;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'blitz_participants'
  ) THEN
    ALTER TABLE public.blitz_participants ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_view_blitz_participants" ON public.blitz_participants;
    DROP POLICY IF EXISTS "user_join_blitz" ON public.blitz_participants;
    DROP POLICY IF EXISTS "user_leave_blitz" ON public.blitz_participants;

    CREATE POLICY "anyone_view_blitz_participants" ON public.blitz_participants
      FOR SELECT TO authenticated USING (true);

    SELECT column_name INTO v_member_col
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'blitz_participants'
      AND column_name IN ('user_id', 'player_id', 'profile_id')
    ORDER BY CASE column_name
      WHEN 'user_id' THEN 1
      WHEN 'player_id' THEN 2
      ELSE 3
    END
    LIMIT 1;

    IF v_member_col IS NOT NULL THEN
      v_sql := format(
        'CREATE POLICY user_join_blitz ON public.blitz_participants
           FOR INSERT TO authenticated
           WITH CHECK (%I = auth.uid())',
        v_member_col
      );
      EXECUTE v_sql;

      v_sql := format(
        'CREATE POLICY user_leave_blitz ON public.blitz_participants
           FOR DELETE TO authenticated
           USING (%I = auth.uid())',
        v_member_col
      );
      EXECUTE v_sql;
    END IF;
  END IF;
END $$;

-- ===========================================
-- 9. VIEŠIEJI KATALOGAI - skaitymas visiems, super admin redaguoja
-- ===========================================

ALTER TABLE public.sports_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "sports_catalog_select" ON public.sports_catalog;
DROP POLICY IF EXISTS "anyone_read_sports_catalog" ON public.sports_catalog;
DROP POLICY IF EXISTS "super_admin_manage_sports_catalog" ON public.sports_catalog;

CREATE POLICY "anyone_read_sports_catalog" ON public.sports_catalog
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "super_admin_manage_sports_catalog" ON public.sports_catalog
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_super_admin = true
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_super_admin = true
  ));

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'sport_image_templates'
  ) THEN
    ALTER TABLE public.sport_image_templates ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_read_sport_images" ON public.sport_image_templates;
    DROP POLICY IF EXISTS "super_admin_manage_sport_images" ON public.sport_image_templates;

    CREATE POLICY "anyone_read_sport_images" ON public.sport_image_templates
      FOR SELECT TO authenticated USING (true);

    CREATE POLICY "super_admin_manage_sport_images" ON public.sport_image_templates
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ));
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'rules_templates'
  ) THEN
    ALTER TABLE public.rules_templates ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_read_rules" ON public.rules_templates;
    DROP POLICY IF EXISTS "super_admin_manage_rules" ON public.rules_templates;

    CREATE POLICY "anyone_read_rules" ON public.rules_templates
      FOR SELECT TO authenticated USING (true);

    CREATE POLICY "super_admin_manage_rules" ON public.rules_templates
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ));
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'xp_rules'
  ) THEN
    ALTER TABLE public.xp_rules ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "anyone_read_xp_rules" ON public.xp_rules;
    DROP POLICY IF EXISTS "super_admin_manage_xp_rules" ON public.xp_rules;

    CREATE POLICY "anyone_read_xp_rules" ON public.xp_rules
      FOR SELECT TO authenticated USING (true);

    CREATE POLICY "super_admin_manage_xp_rules" ON public.xp_rules
      FOR ALL TO authenticated
      USING (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ))
      WITH CHECK (EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND is_super_admin = true
      ));
  END IF;
END $$;

-- =============================================================================
-- ROLLBACK (jei reikia greitai grįžti — paleisk rankiniu būdu Supabase Editor)
-- =============================================================================
--
-- ALTER TABLE public.direct_chats DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.direct_messages DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.user_sports DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.external_records DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.match_sets DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.match_player_stats DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.ranking_history DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.teams DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.team_members DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.team_invitations DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.open_matches DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.blitz_lobbies DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.blitz_participants DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.sports_catalog DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.sport_image_templates DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.rules_templates DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.xp_rules DISABLE ROW LEVEL SECURITY;
--
-- Po DISABLE galima atkurti senas policies iš 20260521000004_rls.sql
