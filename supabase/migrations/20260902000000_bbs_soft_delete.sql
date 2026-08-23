-- ==============================================================================
-- Migration: bbs_soft_delete
-- 掲示板（bbs_posts / bbs_comments）を「物理削除」から「論理削除（ソフトデリート）」へ変更
--
-- 目的:
--   ポスト・コメント（親含む）を削除しても、その1件だけを「削除されました」表示にし、
--   他のユーザーの返信・投稿は全て残す。
--
-- 変更内容:
--   1. is_deleted カラム追加
--   2. ソフトデリート用RPC（本人のみ）
--      - delete_bbs_post / delete_bbs_comment
--      - 削除時に content / image を NULL に落とす（プライバシー）
--      - 付随する「募集中(pending)」のレスバは cancelled に更新（応募も解放）
--   3. 取得RPCに is_deleted を追加
--   4. クライアントからの物理削除（DELETEポリシー）を廃止し、RPC経由に一本化
-- ==============================================================================

-- ---------- 1. is_deleted カラム ----------
ALTER TABLE public.bbs_posts
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL;

ALTER TABLE public.bbs_comments
  ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false NOT NULL;

CREATE INDEX IF NOT EXISTS bbs_posts_is_deleted_idx ON public.bbs_posts (is_deleted);
CREATE INDEX IF NOT EXISTS bbs_comments_is_deleted_idx ON public.bbs_comments (is_deleted);


-- ---------- 2. ポストの論理削除RPC（本人のみ） ----------
CREATE OR REPLACE FUNCTION public.delete_bbs_post(
  p_post_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 本人の投稿のみ論理削除（本文・画像は残さない）
  UPDATE public.bbs_posts
     SET is_deleted = true,
         content = NULL,
         image_urls = NULL
   WHERE id = p_post_id AND user_id = v_user_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;

  -- 付随する募集中(pending)レスバとその応募をキャンセル（応募者を解放）
  UPDATE public.battle_invites
     SET status = 'cancelled', updated_at = now()
   WHERE attach_type = 'post' AND attach_id = p_post_id AND status = 'pending';

  UPDATE public.battle_invite_applications a
     SET status = 'cancelled', updated_at = now()
    FROM public.battle_invites b
   WHERE b.attach_type = 'post' AND b.attach_id = p_post_id
     AND a.invite_id = b.id AND a.status = 'pending';

  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_bbs_post(uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_bbs_post(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_bbs_post(uuid) TO service_role;


-- ---------- 3. コメントの論理削除RPC（本人のみ） ----------
CREATE OR REPLACE FUNCTION public.delete_bbs_comment(
  p_comment_id uuid
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'UNAUTHORIZED');
  END IF;

  -- 本人のコメントのみ論理削除（本文・画像は残さない。返信の親としての行は残す）
  UPDATE public.bbs_comments
     SET is_deleted = true,
         content = NULL,
         image_url = NULL
   WHERE id = p_comment_id AND user_id = v_user_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;

  -- 付随する募集中(pending)レスバとその応募をキャンセル
  UPDATE public.battle_invites
     SET status = 'cancelled', updated_at = now()
   WHERE attach_type = 'comment' AND attach_id = p_comment_id AND status = 'pending';

  UPDATE public.battle_invite_applications a
     SET status = 'cancelled', updated_at = now()
    FROM public.battle_invites b
   WHERE b.attach_type = 'comment' AND b.attach_id = p_comment_id
     AND a.invite_id = b.id AND a.status = 'pending';

  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_bbs_comment(uuid) TO anon;
GRANT ALL ON FUNCTION public.delete_bbs_comment(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.delete_bbs_comment(uuid) TO service_role;


-- ---------- 4. 取得RPC: ポスト一覧に is_deleted を追加 ----------
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
  has_resba      boolean,
  is_deleted     boolean
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
              AND b.status IN ('pending', 'accepted')) AS has_resba,
    p.is_deleted
  FROM bbs_posts p
  LEFT JOIN users u ON u.id = p.user_id
  ORDER BY p.created_at DESC
  LIMIT p_limit;
END;
$$;

GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_posts_with_status(uuid, integer) TO service_role;


-- ---------- 5. 取得RPC: コメント一覧に is_deleted を追加 ----------
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
  has_resba         boolean,
  is_deleted        boolean
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
              AND b.status IN ('pending', 'accepted')) AS has_resba,
    c.is_deleted
  FROM bbs_comments c
  LEFT JOIN users u ON u.id = c.user_id
  WHERE c.post_id = p_post_id
  ORDER BY c.created_at ASC;
END;
$$;

GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_bbs_comments_with_status(uuid, uuid) TO service_role;


-- ---------- 6. クライアントからの物理削除を廃止（RPC経由のソフトデリートに一本化） ----------
-- ※ service_role / postgres は RLS をバイパスするため、管理用の物理削除は従来通り可能。
DROP POLICY IF EXISTS "自分の投稿のみ削除可能" ON public.bbs_posts;
DROP POLICY IF EXISTS "自分のコメントのみ削除可能" ON public.bbs_comments;
