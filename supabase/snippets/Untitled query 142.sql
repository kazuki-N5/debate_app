-- ============================================================
-- Migration: resba_comment_open
-- 返信（コメント）のレスバを「指名型」から「募集型」に変更
--  ・attach_resba_to_comment : target_user_id を NULL にし、誰でも「⚔️ 応じる」できるように
--  ・apply_post_resba       : comment 型も応募を許可（post と同様）
--  ・ホスト（レスバを付けた人）に全画面ダイアログで応募が通知される
-- ============================================================

-- ---------- 1. 返信のレスバを募集型に ----------
CREATE OR REPLACE FUNCTION public.attach_resba_to_comment(
  p_sender_id  uuid,
  p_comment_id uuid,
  p_theme      text,
  p_choice1    text,
  p_choice2    text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_comment_user uuid;
  v_parent       uuid;
  v_post_id      uuid;
  v_invite       json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id, parent_comment_id, post_id
    INTO v_comment_user, v_parent, v_post_id
    FROM bbs_comments WHERE id = p_comment_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'COMMENT_NOT_FOUND');
  END IF;

  -- ポスト型と同じく「誰でも応募可」（target_user_id は NULL）
  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'comment', p_comment_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.attach_resba_to_comment(uuid, uuid, text, text, text) TO service_role;

-- ---------- 2. 応募を comment 型にも許可 ----------
CREATE OR REPLACE FUNCTION public.apply_post_resba(
  p_invite_id uuid,
  p_user_id   uuid
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite battle_invites%ROWTYPE;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.attach_type NOT IN ('post', 'comment') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_TYPE');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.sender_id = p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_APPLY');
  END IF;
  IF public.is_user_in_battle(p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;
  IF EXISTS (SELECT 1 FROM battle_invite_applications WHERE applicant_id = p_user_id AND status = 'pending') THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING');
  END IF;

  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id);

  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO service_role;
