-- Stock library cover attribution (Unsplash / Pexels / Pixabay)
ALTER TABLE tournaments
  ADD COLUMN IF NOT EXISTS image_photographer text,
  ADD COLUMN IF NOT EXISTS image_source text,
  ADD COLUMN IF NOT EXISTS image_source_url text;

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS image_photographer text,
  ADD COLUMN IF NOT EXISTS image_source text,
  ADD COLUMN IF NOT EXISTS image_source_url text;

ALTER TABLE tournaments DROP CONSTRAINT IF EXISTS valid_cover_source;
ALTER TABLE tournaments ADD CONSTRAINT valid_cover_source
  CHECK (cover_source IN ('ai_cache', 'organizer_upload', 'ai_generated', 'stock_library'));

ALTER TABLE events DROP CONSTRAINT IF EXISTS valid_cover_source_events;
ALTER TABLE events ADD CONSTRAINT valid_cover_source_events
  CHECK (cover_source IN ('ai_cache', 'organizer_upload', 'ai_generated', 'stock_library'));
