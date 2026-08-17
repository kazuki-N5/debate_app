-- ==============================================================================
-- 1. 各テーブルへの画像URLカラム追加
-- ==============================================================================

-- 掲示板ポスト (最大4枚のURLを保存するため TEXT配列)
ALTER TABLE public.bbs_posts ADD COLUMN IF NOT EXISTS image_urls TEXT[];

-- 掲示板コメント (1枚)
ALTER TABLE public.bbs_comments ADD COLUMN IF NOT EXISTS image_url TEXT;

-- オープンチャットメッセージ (1枚)
ALTER TABLE public.open_chat_messages ADD COLUMN IF NOT EXISTS image_url TEXT;

-- DMメッセージ (1枚)
ALTER TABLE public.dm_messages ADD COLUMN IF NOT EXISTS image_url TEXT;


-- ==============================================================================
-- 2. 掲示板ポスト一覧取得用RPC (画像配列を含めるように更新)
-- ==============================================================================
DROP FUNCTION IF EXISTS get_bbs_posts_with_status(UUID, INT);

CREATE OR REPLACE FUNCTION get_bbs_posts_with_status(p_user_id UUID, p_limit INT DEFAULT 50)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  likes_count INT,
  replies_count INT,
  image_urls TEXT[], -- 追加
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
    p.image_urls, -- 追加
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;


-- ==============================================================================
-- 3. 掲示板コメント一覧取得用RPC (画像を含めるように更新)
-- ==============================================================================
DROP FUNCTION IF EXISTS get_bbs_comments_with_status(UUID, UUID);

CREATE OR REPLACE FUNCTION get_bbs_comments_with_status(p_post_id UUID, p_user_id UUID)
RETURNS TABLE (
  id UUID,
  post_id UUID,
  user_id UUID,
  parent_comment_id UUID,
  content TEXT,
  created_at TIMESTAMPTZ,
  likes_count INT,
  image_url TEXT, -- 追加
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
    c.image_url, -- 追加
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = p_user_id) AS is_liked_by_me
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$$ LANGUAGE plpgsql;