-- =============================================================================
-- QORT: 1000 XP welcome bonus naujiems vartotojams
-- Paleiskite SQL Editor → Run (jei DB jau egzistuoja)
-- =============================================================================

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
    1000,
    0,
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
