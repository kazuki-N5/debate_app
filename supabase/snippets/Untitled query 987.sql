-- =====================================================
-- 1. Storageバケットの作成（公開アクセス可能なパブリックバケット）
-- =====================================================

-- avatars (プロフィール画像用)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('avatars', 'avatars', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- chat_images (DM / オープンチャットの添付画像用)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('chat_images', 'chat_images', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- bbs_images (掲示板の投稿・コメント添付画像用)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('bbs_images', 'bbs_images', true, 10485760, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;

-- open_chat_images (オープンチャットのルームアイコン画像用)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('open_chat_images', 'open_chat_images', true, 5242880, ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/gif'])
ON CONFLICT (id) DO UPDATE SET public = true;


-- =====================================================
-- 2. RLSポリシーの設定（読み取り・アップロード・更新・削除）
-- =====================================================

-- 既存の重複ポリシーを削除（再実行時のエラー防止）
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload objects" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own objects" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own objects" ON storage.objects;

-- ① 全員（匿名含む）に画像閲覧（ダウンロード・URL表示）を許可
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING (bucket_id IN ('avatars', 'chat_images', 'bbs_images', 'open_chat_images'));

-- ② ログイン（認証済み）ユーザーに画像アップロードを許可
CREATE POLICY "Authenticated users can upload objects"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id IN ('avatars', 'chat_images', 'bbs_images', 'open_chat_images'));

-- ③ ログインユーザーに画像更新を許可
CREATE POLICY "Users can update own objects"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id IN ('avatars', 'chat_images', 'bbs_images', 'open_chat_images'));

-- ④ ログインユーザーに画像削除を許可
CREATE POLICY "Users can delete own objects"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id IN ('avatars', 'chat_images', 'bbs_images', 'open_chat_images'));