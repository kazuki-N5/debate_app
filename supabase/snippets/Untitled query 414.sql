-- 1. ストレージバケットの作成（存在しない場合のみ作成、public = true で一般公開設定）
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('chat_images', 'chat_images', true),
  ('bbs_images', 'bbs_images', true),
  ('open_chat_images', 'open_chat_images', true),
  ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. 既存の同一名ポリシーがあれば削除（重複エラー防止）
DROP POLICY IF EXISTS "Public can view bucket images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload bucket images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update bucket images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete bucket images" ON storage.objects;

-- 3. 全員（ログイン不要含む）に画像閲覧（SELECT）を許可
CREATE POLICY "Public can view bucket images"
ON storage.objects FOR SELECT
USING ( bucket_id IN ('chat_images', 'bbs_images', 'open_chat_images', 'avatars') );

-- 4. ログイン済みユーザーに画像アップロード（INSERT）を許可
CREATE POLICY "Authenticated users can upload bucket images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK ( bucket_id IN ('chat_images', 'bbs_images', 'open_chat_images', 'avatars') );

-- 5. ログイン済みユーザーに画像更新（UPDATE）を許可
CREATE POLICY "Authenticated users can update bucket images"
ON storage.objects FOR UPDATE
TO authenticated
USING ( bucket_id IN ('chat_images', 'bbs_images', 'open_chat_images', 'avatars') );

-- 6. ログイン済みユーザーに画像削除（DELETE）を許可
CREATE POLICY "Authenticated users can delete bucket images"
ON storage.objects FOR DELETE
TO authenticated
USING ( bucket_id IN ('chat_images', 'bbs_images', 'open_chat_images', 'avatars') );