-- =============================================================================
-- QORT: Trigeriai
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Naujas auth vartotojas → profiles įrašas
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, email, nickname, xp, q_coins, onboarding_complete
  )
  VALUES (
    NEW.id,
    NEW.email,
    'Vartotojas',
    0,
    0,
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- -----------------------------------------------------------------------------
-- Mačas užbaigtas → XP paskirstymas (vieną kartą)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trigger_match_completed_xp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed'
     AND (OLD.status IS DISTINCT FROM 'completed') THEN
    PERFORM public.distribute_match_xp(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_match_completed_xp ON public.matches;
CREATE TRIGGER on_match_completed_xp
  AFTER UPDATE OF status ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_match_completed_xp();

-- -----------------------------------------------------------------------------
-- updated_at automatinis atnaujinimas (matches)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'matches' AND column_name = 'updated_at'
  ) THEN
    DROP TRIGGER IF EXISTS set_matches_updated_at ON public.matches;
    CREATE TRIGGER set_matches_updated_at
      BEFORE UPDATE ON public.matches
      FOR EACH ROW
      EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;
