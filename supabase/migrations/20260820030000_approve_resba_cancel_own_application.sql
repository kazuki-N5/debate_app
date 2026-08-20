-- ============================================================
-- Migration: approve_resba_cancel_own_application
-- ポスト/返信レスバの承認（approve_post_resba）で、
-- 「ホスト自身が応募中のまま試合を開始してしまう」問題を修正
--
-- 背景:
--   DM承諾（respond_resba）は承諾者の保留応募を自動キャンセルするが、
--   ポスト/返信の承認（approve_post_resba）にはその処理が無く、
--   ホストは「自分の保留応募」を残したまま試合を開始できた。
--   その後、応募先のホストが承認すると、進行中の試合が
--   is_user_in_battle（解決型）により自動的に「前の試合を放棄」とされ
--   ホストは気づかぬうちに試合を失っていた。
--
-- 対処:
--   承認成功時にホスト自身の保留応募を cancelled にする（DM承諾と同じ整合性）。
--   → 応募先のホストは承認できなくなり（APPLICATION_CLOSED）、
--     進行中の試合が勝手に負けになることはなくなる。
-- ============================================================

CREATE OR REPLACE FUNCTION public.approve_post_resba(
  p_invite_id      uuid,
  p_application_id uuid,
  p_host_id        uuid,
  p_approve        boolean
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite battle_invites%ROWTYPE;
  v_app    battle_invite_applications%ROWTYPE;
  v_room_id uuid;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.sender_id <> p_host_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_HOST');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;

  SELECT * INTO v_app FROM battle_invite_applications
   WHERE id = p_application_id AND invite_id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'APPLICATION_NOT_FOUND');
  END IF;
  IF v_app.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'APPLICATION_CLOSED');
  END IF;

  IF p_approve = TRUE THEN
    -- ★ ホスト自身が対戦中なら却下
    IF public.is_user_in_battle(p_host_id) THEN
      RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
    END IF;
    -- ★ 応募者が対戦中なら却下（応募者がランダムマッチ等で対戦中でも二重試合を防ぐ）
    IF public.is_user_in_battle(v_app.applicant_id) THEN
      RETURN json_build_object('success', false, 'error', 'APPLICANT_IN_BATTLE');
    END IF;

    -- rooms_v2 でバトル開始（選択肢未指定時は賛成/反対）
    INSERT INTO rooms_v2 (player1_id, player2_id, current_theme, current_choice1, current_choice2, theme_s, is_matched, is_bbs)
    VALUES (
      v_invite.sender_id, v_app.applicant_id,
      COALESCE(NULLIF(v_invite.theme, ''), 'レスバ対戦'),
      COALESCE(NULLIF(v_invite.choice1, ''), '賛成'),
      COALESCE(NULLIF(v_invite.choice2, ''), '反対'),
      TRUE, TRUE, TRUE
    )
    RETURNING id INTO v_room_id;

    UPDATE battle_invites
       SET status = 'accepted', responder_id = v_app.applicant_id,
           battle_room_id = v_room_id, responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;

    UPDATE battle_invite_applications
       SET status = 'accepted', updated_at = now()
     WHERE id = p_application_id;

    -- 他の応募を自動却下
    UPDATE battle_invite_applications
       SET status = 'rejected', updated_at = now()
     WHERE invite_id = p_invite_id AND id <> p_application_id AND status = 'pending';

    -- ★ ホスト自身の保留応募も自動キャンセル（応募中に試合開始した場合の二重化防止）
    --   DM承諾（respond_resba）と同じ整合性。これにより応募先のホストは
    --   承認できなくなり（APPLICATION_CLOSED）、進行中の試合が勝手に負けにならない。
    UPDATE battle_invite_applications
       SET status = 'cancelled', updated_at = now()
     WHERE applicant_id = p_host_id AND status = 'pending';

    RETURN json_build_object('success', true, 'room_id', v_room_id);
  ELSE
    UPDATE battle_invite_applications
       SET status = 'rejected', updated_at = now()
     WHERE id = p_application_id;
    RETURN json_build_object('success', true);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO anon;
GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.approve_post_resba(uuid, uuid, uuid, boolean) TO service_role;
