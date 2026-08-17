-- ==============================================================================
-- 4. ストレージバケットの作成とポリシー設定
-- ==============================================================================

-- バケットの作成 (すでに存在する場合はエラーを無視する設定が難しいため、存在しない場合のみ作成するような処理にするか、単にINSERT ON CONFLICTを使います)
INSERT INTO storage.buckets (id, name, public) 
VALUES 
  ('bbs_images', 'bbs_images', true),
  ('chat_images', 'chat_images', true)
ON CONFLICT (id) DO NOTHING;

-- ==============================================================================
-- 5. ストレージのセキュリティポリシー (RLS)
-- ==============================================================================

-- 誰もが画像を閲覧できるようにする (SELECT)
CREATE POLICY "bbs_images_public_select" ON storage.objects 
FOR SELECT USING (bucket_id = 'bbs_images');

CREATE POLICY "chat_images_public_select" ON storage.objects 
FOR SELECT USING (bucket_id = 'chat_images');

-- 認証済みユーザーのみが画像をアップロードできるようにする (INSERT)
CREATE POLICY "bbs_images_auth_insert" ON storage.objects 
FOR INSERT WITH CHECK (bucket_id = 'bbs_images' AND auth.role() = 'authenticated');

CREATE POLICY "chat_images_auth_insert" ON storage.objects 
FOR INSERT WITH CHECK (bucket_id = 'chat_images' AND auth.role() = 'authenticated');