-- Kai open_match priimamas/uždaromas — pašalinti feed skelbimą

CREATE OR REPLACE FUNCTION public.cleanup_feed_post_open_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status IN ('accepted', 'closed', 'completed')
     AND (OLD IS NULL OR OLD.status IS DISTINCT FROM NEW.status) THEN
    DELETE FROM public.feed_posts
    WHERE source_table = 'open_matches' AND source_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_cleanup_feed_open_match ON public.open_matches;
CREATE TRIGGER trigger_cleanup_feed_open_match
  AFTER UPDATE OF status ON public.open_matches
  FOR EACH ROW
  EXECUTE FUNCTION public.cleanup_feed_post_open_match();
