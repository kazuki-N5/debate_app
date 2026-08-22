-- ==============================================================================
-- 掲示板ポスト一覧およびコメント一覧取得RPCの修正
-- 画像カラム（image_urls / image_url）とレスバ有無（has_resba）を同時に正しく返却するように統合
-- SECURITY DEFINER を付与して、RLSにブロックされずに has_resba を正しく判定・返却する
-- ==============================================================================

-- 1. ポスト一覧取得RPC
DROP FUNCTION IF EXISTS public.get_bbs_posts_with_status(uuid, integer);

CREATE OR REPLACE FUNCTION public.get_bbs_posts_with_status (
  p_user_id uuid,
  p_limit   integer DEFAULT 50
)
RETURNS TABLE (
  id             uuid,
  user_id        uuid,
  content        text,
  created_at     timestamp with time zone,
  likes_count    integer,
  replies_count  integer,
  image_urls     text[],
  users          json,
  is_liked_by_me boolean,
  has_resba      boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    p.content,
    p.created_at,
    p.likes_count,
    p.replies_count,
    p.image_urls,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_likes l WHERE l.post_id = p.id AND l.user_id = p_user_id) AS is_liked_by_me,
    EXISTS(SELECT 1 FROM battle_invites b
            WHERE b.attach_type = 'post' AND b.attach_id = p.id
              AND b.status IN ('pending', 'accepted')) AS has_resba
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO service_role;


-- 2. コメント一覧取得RPC
DROP FUNCTION IF EXISTS public.get_bbs_comments_with_status(uuid, uuid);

CREATE OR REPLACE FUNCTION public.get_bbs_comments_with_status (
  p_post_id uuid,
  p_user_id uuid
)
RETURNS TABLE (
  id                uuid,
  post_id           uuid,
  user_id           uuid,
  parent_comment_id uuid,
  content           text,
  created_at        timestamp with time zone,
  likes_count       integer,
  image_url         text,
  users             json,
  is_liked_by_me    boolean,
  has_resba         boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
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
    c.image_url,
    row_to_json(u) AS users,
    EXISTS(SELECT 1 FROM bbs_comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = p_user_id) AS is_liked_by_me,
    EXISTS(SELECT 1 FROM battle_invites b
            WHERE b.attach_type = 'comment' AND b.attach_id = c.id
              AND b.status IN ('pending', 'accepted')) AS has_resba
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$$;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO service_role;
