-- =============================================================================
-- QORT: Storage bucket politikos
-- Prieš paleidžiant: sukurkite bucket'us Dashboard → Storage
-- avatars, images, team-logos, tournament-images (public)
-- =============================================================================

-- Avatars
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_auth_upload" ON storage.objects;
CREATE POLICY "avatars_auth_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
CREATE POLICY "avatars_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'avatars' AND owner = auth.uid());

-- Images (profilio nuotraukos)
DROP POLICY IF EXISTS "images_public_read" ON storage.objects;
CREATE POLICY "images_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'images');

DROP POLICY IF EXISTS "images_auth_upload" ON storage.objects;
CREATE POLICY "images_auth_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'images' AND owner = auth.uid());

-- Team logos
DROP POLICY IF EXISTS "team_logos_public_read" ON storage.objects;
CREATE POLICY "team_logos_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'team-logos');

DROP POLICY IF EXISTS "team_logos_auth_upload" ON storage.objects;
CREATE POLICY "team_logos_auth_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'team-logos' AND owner = auth.uid());

-- Tournament images
DROP POLICY IF EXISTS "tournament_images_public_read" ON storage.objects;
CREATE POLICY "tournament_images_public_read" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'tournament-images');

DROP POLICY IF EXISTS "tournament_images_auth_upload" ON storage.objects;
CREATE POLICY "tournament_images_auth_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'tournament-images' AND owner = auth.uid());
