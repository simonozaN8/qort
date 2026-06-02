-- Super-admin flag (platform-wide, ne turnyro owner)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_super_admin boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.is_super_admin IS
  'QORT platform super-admin: be AI vaizdų generavimo limitų, event approval ir pan.';

-- Spalvų filtro preset id (taikomas UI, ne perrašo image_url)
ALTER TABLE public.tournaments
  ADD COLUMN IF NOT EXISTS cover_filter_preset text;

COMMENT ON COLUMN public.tournaments.cover_filter_preset IS
  'Cover ColorFilter preset: original | cool_dark | warm_vibrant | bw_yellow_accent';
