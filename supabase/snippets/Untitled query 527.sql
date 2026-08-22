-- ============================================================
-- Migration: fix_cancel_resba_application_cleanup
-- ホストがレスバを取り下げた / 投稿・コメントを削除したときに、
-- 応募中(pending)の応募者が「応募中」のまま残らないようにする
--
-- 修正前の問題:
--  - cancel_resba : invite を cancelled にするだけで battle_invite_applications は
--                   pending のまま → 応募者は永遠に「応募中」扱いになり、
--                   他のレスバに応募できなくなる(ALREADY_APPLYING)
--  - 投稿/コメント削除 : 付随レスバが pending のまま残る
--
-- 修正後:
--  - cancel_resba : 取り下げと同時に pending 応募を cancelled に更新(応募者を解放)
--  - bbs_posts / bbs_comments 削除時 : 付随する pending レスバと応募を cancelled に更新
--  ※ delete_resba(完全削除)は FK ON DELETE CASCADE で応募も消えるため対応不要
-- ============================================================

-- ---------- 1. cancel_resba: 取り下げと同時に応募を解放 ----------
CREATE OR REPLACE FUNCTION public.cancel_resba(
  p_invite_id uuid,
  p_sender_id uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_id uuid;
BEGIN
  UPDATE battle_invites
     SET status = 'cancelled', updated_at = now()
   WHERE id = p_invite_id AND sender_id = p_sender_id AND status = 'pending'
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'NOT_FOUND_OR_UNAUTHORIZED');
  END IF;

  -- ★ 応募中だったユーザーを解放する(応募側はリアルタイムで解放される)
  UPDATE battle_invite_applications
     SET status = 'cancelled', updated_at = now()
   WHERE invite_id = v_id AND status = 'pending';

  RETURN json_build_object('success', true);
END;
$function$;

-- ---------- 2. 投稿/コメント削除時に付随レスバと応募を解放 ----------
CREATE OR REPLACE FUNCTION public.cancel_resbas_on_content_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_attach_type text;
BEGIN
  IF TG_TABLE_NAME = 'bbs_posts' THEN
    v_attach_type := 'post';
  ELSIF TG_TABLE_NAME = 'bbs_comments' THEN
    v_attach_type := 'comment';
  ELSE
    RETURN OLD;
  END IF;

  -- 付随する募集中(pending)のレスバを取り下げ
  UPDATE battle_invites
     SET status = 'cancelled', updated_at = now()
   WHERE attach_type = v_attach_type AND attach_id = OLD.id AND status = 'pending';

  -- その応募も解放
  UPDATE battle_invite_applications a
     SET status = 'cancelled', updated_at = now()
    FROM battle_invites b
   WHERE b.attach_type = v_attach_type AND b.attach_id = OLD.id
     AND a.invite_id = b.id AND a.status = 'pending';

  RETURN OLD;
END;
$function$;

DROP TRIGGER IF EXISTS trg_cancel_resbas_on_post_delete ON public.bbs_posts;
CREATE TRIGGER trg_cancel_resbas_on_post_delete
  AFTER DELETE ON public.bbs_posts
  FOR EACH ROW EXECUTE FUNCTION public.cancel_resbas_on_content_delete();

DROP TRIGGER IF EXISTS trg_cancel_resbas_on_comment_delete ON public.bbs_comments;
CREATE TRIGGER trg_cancel_resbas_on_comment_delete
  AFTER DELETE ON public.bbs_comments
  FOR EACH ROW EXECUTE FUNCTION public.cancel_resbas_on_content_delete();

-- ---------- 3. 既存データの後始末 ----------
-- 修正前の cancel_resba で取り下げ済み(cancelled)のレスバに
-- pending 応募が残っている不整合を一括解消する(冪等)
UPDATE battle_invite_applications a
   SET status = 'cancelled', updated_at = now()
  FROM battle_invites b
 WHERE b.status = 'cancelled'
   AND a.invite_id = b.id
   AND a.status = 'pending';

