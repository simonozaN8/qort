-- Papildomi indeksai didesnei apkrovai (skelbimai, komandos, paieška)



CREATE INDEX IF NOT EXISTS idx_open_matches_sport_status

  ON public.open_matches (sport, status);



CREATE INDEX IF NOT EXISTS idx_team_members_team_id

  ON public.team_members (team_id);



CREATE INDEX IF NOT EXISTS idx_external_records_user_date

  ON public.external_records (user_id, date_played DESC);



CREATE INDEX IF NOT EXISTS idx_matches_user_status

  ON public.matches (player1_id, status);



CREATE INDEX IF NOT EXISTS idx_matches_user2_status

  ON public.matches (player2_id, status);


