-- ==========================================
-- 開発用: 全テーブル・ストレージの完全許可RLS
-- ==========================================
-- ※ このスクリプトは 匿名(anon) も 認証済み(authenticated) も
-- 何でも許可するフルオープンのポリシーを設定します。

-- 1. Storage (avatarsバケット) のフルオープン設定
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "誰でもアバターを閲覧可能" ON storage.objects;
DROP POLICY IF EXISTS "認証済みユーザーはアバターをアップロード可能" ON storage.objects;
DROP POLICY IF EXISTS "自分のアバターを更新可能" ON storage.objects;
DROP POLICY IF EXISTS "自分のアバターを削除可能" ON storage.objects;
DROP POLICY IF EXISTS "ストレージ完全許可_SELECT" ON storage.objects;
DROP POLICY IF EXISTS "ストレージ完全許可_INSERT" ON storage.objects;
DROP POLICY IF EXISTS "ストレージ完全許可_UPDATE" ON storage.objects;
DROP POLICY IF EXISTS "ストレージ完全許可_DELETE" ON storage.objects;

CREATE POLICY "ストレージ完全許可_SELECT" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "ストレージ完全許可_INSERT" ON storage.objects FOR INSERT WITH CHECK (true);
CREATE POLICY "ストレージ完全許可_UPDATE" ON storage.objects FOR UPDATE USING (true);
CREATE POLICY "ストレージ完全許可_DELETE" ON storage.objects FOR DELETE USING (true);


-- 2. 掲示板テーブル (bbs_posts 等) のフルオープン設定
ALTER TABLE bbs_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_comment_likes ENABLE ROW LEVEL SECURITY;

-- 既存の制限付きポリシーを削除（エラー回避用）
DROP POLICY IF EXISTS "誰でも投稿を閲覧可能" ON bbs_posts;
DROP POLICY IF EXISTS "認証済みユーザーは投稿を作成可能" ON bbs_posts;
DROP POLICY IF EXISTS "自分の投稿のみ更新可能" ON bbs_posts;
DROP POLICY IF EXISTS "自分の投稿のみ削除可能" ON bbs_posts;

DROP POLICY IF EXISTS "誰でもいいねを閲覧可能" ON bbs_likes;
DROP POLICY IF EXISTS "認証済みユーザーはいいねを作成可能" ON bbs_likes;
DROP POLICY IF EXISTS "自分のいいねのみ削除可能" ON bbs_likes;

DROP POLICY IF EXISTS "誰でもコメントを閲覧可能" ON bbs_comments;
DROP POLICY IF EXISTS "認証済みユーザーはコメントを作成可能" ON bbs_comments;
DROP POLICY IF EXISTS "自分のコメントのみ更新可能" ON bbs_comments;
DROP POLICY IF EXISTS "自分のコメントのみ削除可能" ON bbs_comments;

DROP POLICY IF EXISTS "誰でもコメントのいいねを閲覧可能" ON bbs_comment_likes;
DROP POLICY IF EXISTS "認証済みユーザーはコメントのいいねを作成可能" ON bbs_comment_likes;
DROP POLICY IF EXISTS "自分のコメントのいいねのみ削除可能" ON bbs_comment_likes;

-- bbs_posts
CREATE POLICY "bbs_posts完全許可_SELECT" ON bbs_posts FOR SELECT USING (true);
CREATE POLICY "bbs_posts完全許可_INSERT" ON bbs_posts FOR INSERT WITH CHECK (true);
CREATE POLICY "bbs_posts完全許可_UPDATE" ON bbs_posts FOR UPDATE USING (true);
CREATE POLICY "bbs_posts完全許可_DELETE" ON bbs_posts FOR DELETE USING (true);

-- bbs_likes
CREATE POLICY "bbs_likes完全許可_SELECT" ON bbs_likes FOR SELECT USING (true);
CREATE POLICY "bbs_likes完全許可_INSERT" ON bbs_likes FOR INSERT WITH CHECK (true);
CREATE POLICY "bbs_likes完全許可_UPDATE" ON bbs_likes FOR UPDATE USING (true);
CREATE POLICY "bbs_likes完全許可_DELETE" ON bbs_likes FOR DELETE USING (true);

-- bbs_comments
CREATE POLICY "bbs_comments完全許可_SELECT" ON bbs_comments FOR SELECT USING (true);
CREATE POLICY "bbs_comments完全許可_INSERT" ON bbs_comments FOR INSERT WITH CHECK (true);
CREATE POLICY "bbs_comments完全許可_UPDATE" ON bbs_comments FOR UPDATE USING (true);
CREATE POLICY "bbs_comments完全許可_DELETE" ON bbs_comments FOR DELETE USING (true);

-- bbs_comment_likes
CREATE POLICY "bbs_comment_likes完全許可_SELECT" ON bbs_comment_likes FOR SELECT USING (true);
CREATE POLICY "bbs_comment_likes完全許可_INSERT" ON bbs_comment_likes FOR INSERT WITH CHECK (true);
CREATE POLICY "bbs_comment_likes完全許可_UPDATE" ON bbs_comment_likes FOR UPDATE USING (true);
CREATE POLICY "bbs_comment_likes完全許可_DELETE" ON bbs_comment_likes FOR DELETE USING (true);