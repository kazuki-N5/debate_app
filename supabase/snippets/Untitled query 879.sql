-- ==============================================================================
-- 1. いいね数の自動更新トリガー (bbs_posts)
-- ==============================================================================

-- カウントを更新する関数
CREATE OR REPLACE FUNCTION update_bbs_post_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE bbs_posts SET likes_count = likes_count + 1 WHERE id = NEW.post_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE bbs_posts SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.post_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 既存のトリガーがあれば削除
DROP TRIGGER IF EXISTS trigger_update_bbs_post_likes_count ON bbs_likes;

-- トリガーの作成
CREATE TRIGGER trigger_update_bbs_post_likes_count
AFTER INSERT OR DELETE ON bbs_likes
FOR EACH ROW
EXECUTE FUNCTION update_bbs_post_likes_count();


-- ==============================================================================
-- 2. コメントのいいね数の自動更新トリガー (bbs_comments)
-- ==============================================================================

-- カウントを更新する関数
CREATE OR REPLACE FUNCTION update_bbs_comment_likes_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE bbs_comments SET likes_count = likes_count + 1 WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE bbs_comments SET likes_count = GREATEST(likes_count - 1, 0) WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 既存のトリガーがあれば削除
DROP TRIGGER IF EXISTS trigger_update_bbs_comment_likes_count ON bbs_comment_likes;

-- トリガーの作成
CREATE TRIGGER trigger_update_bbs_comment_likes_count
AFTER INSERT OR DELETE ON bbs_comment_likes
FOR EACH ROW
EXECUTE FUNCTION update_bbs_comment_likes_count();


-- ==============================================================================
-- 3. 掲示板ポスト一覧取得用RPC (自分がいいねしたかどうかのフラグ付き)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_bbs_posts_with_status(p_user_id UUID, p_limit INT DEFAULT 50)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  likes_count INT,
  replies_count INT,
  users JSON,
  is_liked_by_me BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.user_id,
    p.content,
    p.created_at,
    p.likes_count,
    p.replies_count,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;


-- ==============================================================================
-- 4. 掲示板コメント一覧取得用RPC (自分がいいねしたかどうかのフラグ付き)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_bbs_comments_with_status(p_post_id UUID, p_user_id UUID)
RETURNS TABLE (
  id UUID,
  post_id UUID,
  user_id UUID,
  parent_comment_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  likes_count INT,
  users JSON,
  is_liked_by_me BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.post_id,
    c.user_id,
    c.parent_comment_id,
    c.content,
    c.created_at,
    c.likes_count,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$$ LANGUAGE plpgsql;