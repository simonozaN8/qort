-- =============================================================================
-- QORT: draft → pending → approved/rejected publikavimo workflow
-- Paleiskite rankiniu būdu Supabase SQL Editor (vieną kartą)
-- =============================================================================

-- 1. Default: nauji renginiai pradeda kaip draft
ALTER TABLE public.events
  ALTER COLUMN approval_status SET DEFAULT 'draft';

-- 2. Atmetimo priežastis (atskirai nuo organizer_note)
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS rejection_reason text;

COMMENT ON COLUMN public.events.rejection_reason IS
  'Super admin komentaras organizatoriui kai approval_status = rejected';

-- 3. CHECK constraint su draft reikšme
ALTER TABLE public.events
  DROP CONSTRAINT IF EXISTS events_approval_status_check;

ALTER TABLE public.events
  ADD CONSTRAINT events_approval_status_check
  CHECK (approval_status IN ('draft', 'pending', 'approved', 'rejected'));

-- 4. RLS — kūrėjas mato savo, super admin mato viską, viešai tik approved
DROP POLICY IF EXISTS "anyone_read_approved_events" ON public.events;
DROP POLICY IF EXISTS "owner_read_own_events" ON public.events;
DROP POLICY IF EXISTS "super_admin_read_all_events" ON public.events;

CREATE POLICY "anyone_read_approved_events" ON public.events
  FOR SELECT TO authenticated
  USING (approval_status = 'approved');

CREATE POLICY "owner_read_own_events" ON public.events
  FOR SELECT TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "super_admin_read_all_events" ON public.events
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.is_super_admin = true
    )
  );
