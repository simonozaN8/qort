-- =============================================================================

-- QORT Fazė 1: universalus mėgėjų sportų katalogas

-- Paleiskite SQL Editor → Run, tada seed_sports_catalog.sql

-- =============================================================================



-- Unikalus sporto pavadinimas

CREATE UNIQUE INDEX IF NOT EXISTS idx_sports_catalog_name

  ON public.sports_catalog (name);



-- --- sports_catalog papildomi laukai ---

ALTER TABLE public.sports_catalog

  ADD COLUMN IF NOT EXISTS family text,

  ADD COLUMN IF NOT EXISTS participant_type text DEFAULT 'individual',

  ADD COLUMN IF NOT EXISTS scoring_type text DEFAULT 'points',

  ADD COLUMN IF NOT EXISTS allowed_formats jsonb DEFAULT '["1v1"]'::jsonb,

  ADD COLUMN IF NOT EXISTS rating_config jsonb DEFAULT '{"model":"level_rp","base_rp":1000}'::jsonb,

  ADD COLUMN IF NOT EXISTS rating_categories jsonb DEFAULT '["open"]'::jsonb,

  ADD COLUMN IF NOT EXISTS is_combat boolean DEFAULT false,

  ADD COLUMN IF NOT EXISTS is_mass_start boolean DEFAULT false,

  ADD COLUMN IF NOT EXISTS sort_order integer DEFAULT 100,

  ADD COLUMN IF NOT EXISTS description text;



-- --- user_sports: reitingas pagal kategoriją ---

ALTER TABLE public.user_sports

  ADD COLUMN IF NOT EXISTS rating_category text DEFAULT 'open';



COMMENT ON COLUMN public.sports_catalog.family IS 'Šeima UI grupavimui: Raketės, Kamuolys, Tikslieji...';

COMMENT ON COLUMN public.sports_catalog.scoring_type IS 'sets | points | goals | frames | legs | match_win';

COMMENT ON COLUMN public.sports_catalog.allowed_formats IS 'Pvz. ["1v1","2v2","5v5"]';

COMMENT ON COLUMN public.user_sports.rating_category IS 'open | vyrai | moterys | mixed | senjorai | jaunimas';


