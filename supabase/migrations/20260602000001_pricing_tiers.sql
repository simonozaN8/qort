-- =============================================================================
-- QORT: Early Bird — pricing_tiers + events.registration_deadline
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.pricing_tiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric NOT NULL,
  valid_until timestamptz,
  display_order int DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pricing_tiers_event
  ON public.pricing_tiers(event_id, display_order);

ALTER TABLE public.pricing_tiers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_manage_tiers" ON public.pricing_tiers;
CREATE POLICY "owner_manage_tiers" ON public.pricing_tiers
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.events
      WHERE events.id = pricing_tiers.event_id
        AND events.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.events
      WHERE events.id = pricing_tiers.event_id
        AND events.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "anyone_read_tiers" ON public.pricing_tiers;
CREATE POLICY "anyone_read_tiers" ON public.pricing_tiers
  FOR SELECT TO authenticated
  USING (true);

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS registration_deadline timestamptz;

-- Pasirinktina: esami turnyrai → viena „Įprasta“ pakopa (paleiskite rankiniu būdu)
-- INSERT INTO public.pricing_tiers (event_id, name, price, valid_until, display_order)
-- SELECT DISTINCT
--   t.event_id,
--   'Įprasta',
--   t.entry_fee,
--   NULL,
--   0
-- FROM public.tournaments t
-- WHERE t.event_id IS NOT NULL
--   AND t.entry_fee IS NOT NULL
--   AND NOT EXISTS (
--     SELECT 1 FROM public.pricing_tiers pt
--     WHERE pt.event_id = t.event_id
--   );
