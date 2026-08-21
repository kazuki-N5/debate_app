-- ============================================================
-- Migration: apply_post_resba_return_application
-- 応募成功時に ApplyingInfo に必要な応募詳細情報をレスポンスで直接返すように拡張
-- ============================================================

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
  v_app_id uuid;
  v_application json;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.attach_type NOT IN ('post', 'comment', 'dm', 'open_chat', 'recruit') THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_TYPE');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.sender_id = p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_APPLY');
  END IF;
  -- ★ ブロック判定(モデレーション対応)
  IF public.is_user_blocked(v_invite.sender_id, p_user_id)
     OR public.is_user_blocked(p_user_id, v_invite.sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'BLOCKED');
  END IF;
  IF public.is_user_in_battle(p_user_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;
  IF EXISTS (SELECT 1 FROM battle_invite_applications WHERE applicant_id = p_user_id AND status = 'pending') THEN
    RETURN json_build_object('success', false, 'error', 'ALREADY_APPLYING');
  END IF;

  -- 再応募対応: 取り下げ(cancelled)・拒否(rejected)済みの行は pending に戻す
  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id)
  ON CONFLICT (invite_id, applicant_id)
  DO UPDATE SET status = 'pending', created_at = now(), updated_at = now()
  RETURNING id INTO v_app_id;

  -- 応募情報を構築して返却
  SELECT json_build_object(
    'application_id', a.id,
    'invite_id', a.invite_id,
    'theme', b.theme,
    'choice1', b.choice1,
    'choice2', b.choice2,
    'host_name', u.name,
    'host_avatar', u.avatar_url,
    'attach_type', b.attach_type,
    'attach_id', b.attach_id,
    'status', a.status,
    'created_at', a.created_at
  ) INTO v_application
  FROM battle_invite_applications a
  JOIN battle_invites b ON b.id = a.invite_id
  JOIN users u ON u.id = b.sender_id
  WHERE a.id = v_app_id;

  RETURN json_build_object('success', true, 'application', v_application);
END;
$function$;

GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.apply_post_resba(uuid, uuid) TO service_role;
