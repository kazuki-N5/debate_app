-- =============================================================
-- Storage バケット再作成
-- supabase db reset で storage.buckets が空になるため、アプリが
-- 利用する全バケットを public として再作成する（IDEMPOTENT）。
-- 既存の open_chat_images マイグレーションは「Public Access」
-- 等の固定ポリシー名を使っていたため、policy名の衝突を避ける
-- ためにバケット名を含むユニーク名でポリシーを作成する。
-- =============================================================

-- 1) バケット作成（既に存在する場合は何もしない）
INSERT INTO storage.buckets (id, name, public) VALUES
  ('avatars',          'avatars',          true),
  ('open_chat_images', 'open_chat_images', true),
  ('chat_images',      'chat_images',      true),
  ('bbs_images',       'bbs_images',       true)
ON CONFLICT (id) DO NOTHING;

-- 2) storage.objects の RLS ポリシー作成
--    (public 読み取り + 認証ユーザーの insert/update/delete)
DO $$
DECLARE
  b text;
BEGIN
  FOREACH b IN ARRAY ARRAY['avatars','open_chat_images','chat_images','bbs_images']
  LOOP
    -- 公開読み取り
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname = b || '_public_select'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON storage.objects FOR SELECT TO public USING ( bucket_id = ''%s'' )',
        b || '_public_select', b
      );
    END IF;

    -- 認証ユーザー書き込み (INSERT)
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname = b || '_auth_insert'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON storage.objects FOR INSERT TO authenticated WITH CHECK ( bucket_id = ''%s'' AND auth.role() = ''authenticated'' )',
        b || '_auth_insert', b
      );
    END IF;

    -- 認証ユーザー更新 (UPDATE)
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname = b || '_auth_update'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON storage.objects FOR UPDATE TO authenticated USING ( bucket_id = ''%s'' AND auth.role() = ''authenticated'' )',
        b || '_auth_update', b
      );
    END IF;

    -- 認証ユーザー削除 (DELETE) -- アバター/ヘッダーの上書き削除に利用
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname = b || '_auth_delete'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON storage.objects FOR DELETE TO authenticated USING ( bucket_id = ''%s'' AND auth.role() = ''authenticated'' )',
        b || '_auth_delete', b
      );
    END IF;
  END LOOP;
END $$;
