-- ============================================================
-- Migration: fix_resba_reapply
-- 応募を取り下げ(cancel)した後に同じレスバへ再応募できるようにする
--
-- 原因: battle_invite_applications の UNIQUE(invite_id, applicant_id) 制約により、
--       取り下げ(cancelled)・拒否(rejected)済みの行が残っていると、
--       再応募の INSERT が duplicate key(23505)で失敗する
--
-- 修正: apply_post_resba で ON CONFLICT を使い、
--       既存の cancelled / rejected 行を pending に戻して再応募を許可する
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

  -- ★ 再応募対応:
  --   取り下げ(cancelled)・拒否(rejected)済みの行が残っていても、
  --   ON CONFLICT で pending に戻すことで重複エラーを回避し、再応募を許可する
  INSERT INTO battle_invite_applications (invite_id, applicant_id)
  VALUES (p_invite_id, p_user_id)
  ON CONFLICT (invite_id, applicant_id)
  DO UPDATE SET status = 'pending', created_at = now(), updated_at = now();

  RETURN json_build_object('success', true);
END;
$function$;
