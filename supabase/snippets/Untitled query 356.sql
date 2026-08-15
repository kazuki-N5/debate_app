CREATE POLICY "Allow ALL operations for everyone on avatars bucket"
ON storage.objects
FOR ALL
TO public
USING (bucket_id = 'avatars')
WITH CHECK (bucket_id = 'avatars');