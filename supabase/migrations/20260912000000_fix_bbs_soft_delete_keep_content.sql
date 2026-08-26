-- ==============================================================================
-- Migration: fix_bbs_soft_delete_keep_content
-- 掲示板の論理削除RPC（delete_bbs_post / delete_bbs_comment）を修正する
--
-- 原因:
--   20260902000000_bbs_soft_delete.sql では削除時に content / image を NULL にしていたが、
--   bbs_posts.content / bbs_comments.content は NOT NULL 制約のため
--   「null value in column "content" ... violates not-null constraint (23502)」が発生していた。
--
-- 修正内容:
--   本文・画像は DB に残したまま is_deleted = true だけ立てる（純粋なソフトデリート）。
--   表示側（Flutter）は is_deleted を見て「このポストは削除されました」等の
--   プレースホルダーを表示するため、データを消す必要はない。
--   返信・子コメント・レスバの関係もすべてそのまま残る。
-- ==============================================================================

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

  -- 本人の投稿のみ論理削除（本文・画像はDBに残し、is_deleted だけ立てる）
  UPDATE public.bbs_posts
     SET is_deleted = true
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

  -- 本人のコメントのみ論理削除（本文・画像はDBに残し、is_deleted だけ立てる。
  -- 返信の親としての行もそのまま残る）
  UPDATE public.bbs_comments
     SET is_deleted = true
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
