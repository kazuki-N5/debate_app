-- =====================================================
-- 1. Storageバケットの作成（存在しない場合作成）
-- =====================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('avatars', 'avatars', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif']),
  ('chat_images', 'chat_images', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif']),
  ('bbs_images', 'bbs_images', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif']),
  ('open_chat_images', 'open_chat_images', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- =====================================================
-- 2. バケット別 RLS ポリシー設定（読み取り・書き込み・更新・削除）
-- =====================================================

-- -----------------------------------------------------
-- ① avatars バケット用ポリシー
-- -----------------------------------------------------
DROP POLICY IF EXISTS "avatars_public_select" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_auth_delete" ON storage.objects;

CREATE POLICY "avatars_public_select" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "avatars_auth_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "avatars_auth_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'avatars');
CREATE POLICY "avatars_auth_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'avatars');

-- -----------------------------------------------------
-- ② bbs_images バケット用ポリシー
-- -----------------------------------------------------
DROP POLICY IF EXISTS "bbs_images_public_select" ON storage.objects;
DROP POLICY IF EXISTS "bbs_images_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "bbs_images_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "bbs_images_auth_delete" ON storage.objects;

CREATE POLICY "bbs_images_public_select" ON storage.objects FOR SELECT USING (bucket_id = 'bbs_images');
CREATE POLICY "bbs_images_auth_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'bbs_images');
CREATE POLICY "bbs_images_auth_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'bbs_images');
CREATE POLICY "bbs_images_auth_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'bbs_images');

-- -----------------------------------------------------
-- ③ chat_images バケット用ポリシー
-- -----------------------------------------------------
DROP POLICY IF EXISTS "chat_images_public_select" ON storage.objects;
DROP POLICY IF EXISTS "chat_images_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "chat_images_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "chat_images_auth_delete" ON storage.objects;

CREATE POLICY "chat_images_public_select" ON storage.objects FOR SELECT USING (bucket_id = 'chat_images');
CREATE POLICY "chat_images_auth_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'chat_images');
CREATE POLICY "chat_images_auth_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'chat_images');
CREATE POLICY "chat_images_auth_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'chat_images');

-- -----------------------------------------------------
-- ④ open_chat_images バケット用ポリシー
-- -----------------------------------------------------
DROP POLICY IF EXISTS "open_chat_images_public_select" ON storage.objects;
DROP POLICY IF EXISTS "open_chat_images_auth_insert" ON storage.objects;
DROP POLICY IF EXISTS "open_chat_images_auth_update" ON storage.objects;
DROP POLICY IF EXISTS "open_chat_images_auth_delete" ON storage.objects;

CREATE POLICY "open_chat_images_public_select" ON storage.objects FOR SELECT USING (bucket_id = 'open_chat_images');
CREATE POLICY "open_chat_images_auth_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'open_chat_images');
CREATE POLICY "open_chat_images_auth_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'open_chat_images');
CREATE POLICY "open_chat_images_auth_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'open_chat_images');