-- =============================================================================
-- QORT: mokama organizatoriaus paslauga + administratoriaus patvirtinimas
-- Paleiskite SQL Editor → Run (vieną kartą)
-- =============================================================================

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS approval_status text DEFAULT 'approved',
  ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'confirmed',
  ADD COLUMN IF NOT EXISTS organizer_service_fee numeric(10, 2) DEFAULT 49,
  ADD COLUMN IF NOT EXISTS organizer_note text,
  ADD COLUMN IF NOT EXISTS admin_review_note text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES auth.users (id);

UPDATE public.events
SET approval_status = COALESCE(approval_status, 'approved'),
    payment_status = COALESCE(payment_status, 'confirmed')
WHERE approval_status IS NULL;

CREATE INDEX IF NOT EXISTS idx_events_approval_status
  ON public.events (approval_status, created_at DESC);

COMMENT ON COLUMN public.events.approval_status IS
  'pending | approved | rejected — viešas kalendorius rodo tik approved';
