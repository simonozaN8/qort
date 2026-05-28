-- =============================================================================

-- QORT: mėgėjų sportų katalogas (Fazė 1)

-- PALEISKITE PO: 20260521000009_sports_catalog_phase1.sql

-- Saugu kartoti (UPSERT pagal name)

-- =============================================================================



-- Standartiniai 5 mėgėjų lygiai (visoms šakoms)

-- scoring_type: sets | points | goals | frames | legs | match_win

-- participant_type: individual | pair | team | mixed



INSERT INTO public.sports_catalog (

  name, is_active, family, participant_type, scoring_type,

  allowed_formats, rating_config, rating_categories, levels_config,

  is_combat, is_mass_start, sort_order, description

) VALUES

  (

    'Tenisas', true, 'Raketės', 'individual', 'sets',

    '["1v1","2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1200,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","mixed","senjorai","jaunimas"]'::jsonb,

    '[{"level_value":1,"name":"NTRP 2.0","desc":"Pradedantysis mėgėjas"},{"level_value":2,"name":"NTRP 2.5","desc":"Stabilus mėgėjas"},{"level_value":3,"name":"NTRP 3.0","desc":"Klubinis lygis"},{"level_value":4,"name":"NTRP 3.5","desc":"Stiprus mėgėjas"},{"level_value":5,"name":"NTRP 4.0","desc":"Konkurencinis mėgėjas"},{"level_value":6,"name":"NTRP 4.5+","desc":"Aukščiausias mėgėjų lygis"}]'::jsonb,

    false, false, 10,

    'Vienetai ir dvejetai; NTRP tipo lygiai ir RP.'

  ),

  (

    'Padelis', true, 'Raketės', 'pair', 'sets',

    '["2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","mixed","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Žaidžiu retkarčiais"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus žaidėjas"},{"level_value":3,"name":"Klubinis","desc":"Klubo lyga"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus mėgėjas"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjų lygis"}]'::jsonb,

    false, false, 20,

    'Visada 2v2; porų sportas.'

  ),

  (

    'Pickleball', true, 'Raketės', 'mixed', 'points',

    '["1v1","2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","mixed","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi žaisti"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus žaidimas"},{"level_value":3,"name":"Klubinis","desc":"Klubo turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus lygis"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 25,

    'Piklbolas / Pickleball — taškai iki 11.'

  ),

  (

    'Badmintonas', true, 'Raketės', 'individual', 'sets',

    '["1v1","2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","mixed","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Žaidžiu laisvalaikiu"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliariai"},{"level_value":3,"name":"Klubinis","desc":"Klubo varžybos"},{"level_value":4,"name":"Konkurencinis","desc":"Regioninis lygis"},{"level_value":5,"name":"Pažengęs","desc":"Aukštas mėgėjų lygis"}]'::jsonb,

    false, false, 30,

    'Vienetai ir dvejetai; setai iki 21.'

  ),

  (

    'Skvošas', true, 'Raketės', 'individual', 'points',

    '["1v1"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"D klubas","desc":"Pradedantysis"},{"level_value":2,"name":"C klubas","desc":"Mėgėjas"},{"level_value":3,"name":"B klubas","desc":"Stiprus mėgėjas"},{"level_value":4,"name":"A klubas","desc":"Konkurencinis"},{"level_value":5,"name":"Elitinis mėgėjas","desc":"Aukščiausias lygis"}]'::jsonb,

    false, false, 35,

    'Squash — dažniausiai 1v1; taškai per rungtynes.'

  ),

  (

    'Stalo tenisas', true, 'Raketės', 'individual', 'sets',

    '["1v1","2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi"},{"level_value":2,"name":"Mėgėjas","desc":"Klubinis žaidėjas"},{"level_value":3,"name":"Stiprus mėgėjas","desc":"Turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Lygos lygis"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 40,

    'Setai; individualus ir porinis.'

  ),

  (

    'Krepšinis', true, 'Kamuolys', 'team', 'goals',

    '["3x3","5v5"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","vyrai","moterys","mixed","jaunimas","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mėgėjų lyga"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus žaidimas"},{"level_value":3,"name":"Klubinis","desc":"Klubo komanda"},{"level_value":4,"name":"Konkurencinis","desc":"Stipri komanda"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjų lygis"}]'::jsonb,

    false, false, 50,

    '3x3 ir 5v5; įvarčiai / taškai.'

  ),

  (

    'Futbolas', true, 'Kamuolys', 'team', 'goals',

    '["5v5","7v7","11v11"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","vyrai","moterys","jaunimas","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mėgėjų lyga"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Klubo komanda"},{"level_value":4,"name":"Konkurencinis","desc":"Stipri lyga"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 55,

    'Mini ir didelis laukas; įvarčiai.'

  ),

  (

    'Tinklinis', true, 'Kamuolys', 'team', 'points',

    '["6x6","4x4"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","vyrai","moterys","mixed","jaunimas"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mėgėjų lyga"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Klubo komanda"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus lygis"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 60,

    'Salės tinklinis; setai / taškai.'

  ),

  (

    'Paplūdimio tinklinis', true, 'Kamuolys', 'team', 'points',

    '["2v2","4v4"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","mixed","vyrai","moterys"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 65,

    'Beach volleyball; 2v2 standartas.'

  ),

  (

    'Smiginis', true, 'Tikslieji', 'individual', 'legs',

    '["1v1","2v2"]'::jsonb,

    '{"model":"level_rp","base_rp":1000,"level_rp_caps":[1000,1500,2000,2500,3000]}'::jsonb,

    '["open","vyrai","moterys","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Žaidžiu retkarčiais"},{"level_value":2,"name":"Mėgėjas","desc":"Pub lyga"},{"level_value":3,"name":"Klubinis","desc":"Klubo turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 70,

    'Legų / setų sistema (501, 301).'

  ),

  (

    'Boulingas', true, 'Tikslieji', 'individual', 'frames',

    '["1v1","2v2"]'::jsonb,

    '{"model":"elo","base_rating":1000,"k_factor":24}'::jsonb,

    '["open","vyrai","moterys","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Vid. < 120"},{"level_value":2,"name":"Mėgėjas","desc":"Vid. 120–150"},{"level_value":3,"name":"Klubinis","desc":"Vid. 150–180"},{"level_value":4,"name":"Konkurencinis","desc":"Vid. 180–200"},{"level_value":5,"name":"Pažengęs","desc":"Vid. 200+"}]'::jsonb,

    false, false, 75,

    'Frame / total pin scoring.'

  ),

  (

    'Biliardas', true, 'Tikslieji', 'individual', 'frames',

    '["1v1"]'::jsonb,

    '{"model":"elo","base_rating":1000,"k_factor":24}'::jsonb,

    '["open","vyrai","moterys"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Klubo lyga"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 80,

    '8-ball / 9-ball — partijos (frames).'

  ),

  (

    'Poolas', true, 'Tikslieji', 'individual', 'frames',

    '["1v1","2v2"]'::jsonb,

    '{"model":"elo","base_rating":1000,"k_factor":24}'::jsonb,

    '["open","vyrai","moterys"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi"},{"level_value":2,"name":"Mėgėjas","desc":"Pub lyga"},{"level_value":3,"name":"Klubinis","desc":"Klubo turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 85,

    'Pool / 8-ball — partijos ar race to N.'

  ),

  (

    'Snukeris', true, 'Tikslieji', 'individual', 'frames',

    '["1v1"]'::jsonb,

    '{"model":"elo","base_rating":1000,"k_factor":20}'::jsonb,

    '["open","vyrai","moterys","senjorai"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mokausi"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Klubo lyga"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 90,

    'Frame-based; best of N frames.'

  ),

  (

    'Dažasvydis', true, 'Komandinis', 'team', 'match_win',

    '["5v5","7v7"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","vyrai","moterys","jaunimas"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mėgėjų lyga"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Komandos turnyrai"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 95,

    'Komandinis taktinis; rungtynių / round laimėjimai (ne kovos sportas).'

  ),

  (

    'Rankinis', true, 'Kamuolys', 'team', 'goals',

    '["6v6","7v7"]'::jsonb,

    '{"model":"team_rp","base_rp":1000}'::jsonb,

    '["open","vyrai","moterys","mixed"]'::jsonb,

    '[{"level_value":1,"name":"Pradedantysis","desc":"Mėgėjų lyga"},{"level_value":2,"name":"Mėgėjas","desc":"Reguliarus"},{"level_value":3,"name":"Klubinis","desc":"Klubo komanda"},{"level_value":4,"name":"Konkurencinis","desc":"Stiprus"},{"level_value":5,"name":"Pažengęs","desc":"Top mėgėjas"}]'::jsonb,

    false, false, 100,

    'Rankinis — komandinis, įvarčiai.'

  )

ON CONFLICT (name) DO UPDATE SET

  is_active = EXCLUDED.is_active,

  family = EXCLUDED.family,

  participant_type = EXCLUDED.participant_type,

  scoring_type = EXCLUDED.scoring_type,

  allowed_formats = EXCLUDED.allowed_formats,

  rating_config = EXCLUDED.rating_config,

  rating_categories = EXCLUDED.rating_categories,

  levels_config = EXCLUDED.levels_config,

  is_combat = EXCLUDED.is_combat,

  is_mass_start = EXCLUDED.is_mass_start,

  sort_order = EXCLUDED.sort_order,

  description = EXCLUDED.description;



-- Seni / ne mėgėjų varžybų sportai — neberodomi programėlėje
UPDATE public.sports_catalog SET is_active = false
WHERE name IN (
  'Pool 8',
  'Salės tinklinis',
  'Piklibolas',
  'Piklbolas',
  'Šachmatai',
  'E-Sportas',
  'E-sportas',
  'Bėgimas',
  'Plaukimas',
  'Dviratis',
  'Crossfit',
  'Kovos sportas'
);


