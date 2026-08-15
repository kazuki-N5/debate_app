-- bbs_posts: 投稿を保存するテーブル
CREATE TABLE IF NOT EXISTS bbs_posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  likes_count INT DEFAULT 0,
  replies_count INT DEFAULT 0
);

-- bbs_likes: 投稿に対するいいねを保存するテーブル
CREATE TABLE IF NOT EXISTS bbs_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES bbs_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(post_id, user_id)
);

-- bbs_comments: 投稿に対するコメントや返信を保存するテーブル
CREATE TABLE IF NOT EXISTS bbs_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES bbs_posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  parent_comment_id UUID REFERENCES bbs_comments(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  likes_count INT DEFAULT 0
);

-- コメントのいいねテーブル
CREATE TABLE IF NOT EXISTS bbs_comment_likes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  comment_id UUID REFERENCES bbs_comments(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(comment_id, user_id)
);

-- 以下、カウント更新用のRPC関数

-- 投稿のいいねカウントを増やす
CREATE OR REPLACE FUNCTION increment_likes_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE bbs_posts SET likes_count = likes_count + 1 WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- 投稿のいいねカウントを減らす
CREATE OR REPLACE FUNCTION decrement_likes_count(post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE bbs_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = post_id;
END;
$$ LANGUAGE plpgsql;

-- コメント（返信）の数を増やす
CREATE OR REPLACE FUNCTION increment_replies_count(p_post_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE bbs_posts SET replies_count = replies_count + 1 WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql;

-- コメントのいいねカウントを増やす
CREATE OR REPLACE FUNCTION increment_comment_likes_count(p_comment_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE bbs_comments SET likes_count = likes_count + 1 WHERE id = p_comment_id;
END;
$$ LANGUAGE plpgsql;

-- コメントのいいねカウントを減らす
CREATE OR REPLACE FUNCTION decrement_comment_likes_count(p_comment_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE bbs_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = p_comment_id;
END;
$$ LANGUAGE plpgsql;


-- ==========================================
-- 行単位セキュリティ (RLS) の設定
-- ==========================================

ALTER TABLE bbs_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE bbs_comment_likes ENABLE ROW LEVEL SECURITY;

-- bbs_posts
CREATE POLICY "誰でも投稿を閲覧可能" ON bbs_posts FOR SELECT USING (true);
CREATE POLICY "認証済みユーザーは投稿を作成可能" ON bbs_posts FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "自分の投稿のみ更新可能" ON bbs_posts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "自分の投稿のみ削除可能" ON bbs_posts FOR DELETE USING (auth.uid() = user_id);

-- bbs_likes
CREATE POLICY "誰でもいいねを閲覧可能" ON bbs_likes FOR SELECT USING (true);
CREATE POLICY "認証済みユーザーはいいねを作成可能" ON bbs_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "自分のいいねのみ削除可能" ON bbs_likes FOR DELETE USING (auth.uid() = user_id);

-- bbs_comments
CREATE POLICY "誰でもコメントを閲覧可能" ON bbs_comments FOR SELECT USING (true);
CREATE POLICY "認証済みユーザーはコメントを作成可能" ON bbs_comments FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "自分のコメントのみ更新可能" ON bbs_comments FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "自分のコメントのみ削除可能" ON bbs_comments FOR DELETE USING (auth.uid() = user_id);

-- bbs_comment_likes
CREATE POLICY "誰でもコメントのいいねを閲覧可能" ON bbs_comment_likes FOR SELECT USING (true);
CREATE POLICY "認証済みユーザーはコメントのいいねを作成可能" ON bbs_comment_likes FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "自分のコメントのいいねのみ削除可能" ON bbs_comment_likes FOR DELETE USING (auth.uid() = user_id);