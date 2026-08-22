-- ============================================================
-- Migration: fix_resba_exclusion
-- P0 先行修正：排他制御・競合処理の補強
--
-- 1. respond_resba      : 承諾時に「送信者（ホスト）」の対戦中チェックを追加（二重試合防止）
-- 2. approve_post_resba : 承認時に「ホスト」「応募者」の対戦中チェックを追加
-- 3. レスバは無制限に作成可（上限なし・複数提案OK。承諾で他の pending は自動キャンセル）
-- 4. rooms_v2 の掃除    : result カラム欠落で削除 cron が動かない問題を修正（winner ベースに）
-- ============================================================

-- ---------- 1. respond_resba: 送信者（ホスト）の対戦中チェック追加 ----------
CREATE OR REPLACE FUNCTION public.respond_resba(
  p_invite_id uuid,
  p_user_id   uuid,
  p_approve   boolean
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_invite    battle_invites%ROWTYPE;
  v_room_id   uuid;
BEGIN
  SELECT * INTO v_invite FROM battle_invites WHERE id = p_invite_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_NOT_FOUND');
  END IF;
  IF v_invite.status <> 'pending' THEN
    RETURN json_build_object('success', false, 'error', 'INVITE_CLOSED');
  END IF;
  IF v_invite.target_user_id <> p_user_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_TARGET');
  END IF;

  IF p_approve = TRUE THEN
    -- 承諾者（相手）が対戦中なら却下
    IF public.is_user_in_battle(p_user_id) THEN
      RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
    END IF;
    -- ★ 送信者（ホスト）が対戦中なら却下（二重試合防止）
    IF public.is_user_in_battle(v_invite.sender_id) THEN
      RETURN json_build_object('success', false, 'error', 'SENDER_IN_BATTLE');
    END IF;

    -- rooms_v2 でバトル開始（テーマ・選択肢を引き継ぎ。選択肢未指定時は賛成/反対）
    INSERT INTO rooms_v2 (player1_id, player2_id, current_theme, current_choice1, current_choice2, theme_s, is_matched, is_bbs)
    VALUES (
      v_invite.sender_id, p_user_id,
      COALESCE(NULLIF(v_invite.theme, ''), 'レスバ対戦'),
      COALESCE(NULLIF(v_invite.choice1, ''), '賛成'),
      COALESCE(NULLIF(v_invite.choice2, ''), '反対'),
      TRUE, TRUE, TRUE
    )
    RETURNING id INTO v_room_id;

    UPDATE battle_invites
       SET status = 'accepted', responder_id = p_user_id,
           battle_room_id = v_room_id, responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;

    -- 送信者の他の pending 提案を自動キャンセル（対戦の二重化防止）
    UPDATE battle_invites
       SET status = 'cancelled', updated_at = now()
     WHERE sender_id = v_invite.sender_id AND id <> p_invite_id AND status = 'pending';

    -- 承諾者の保留応募（ポスト型）も自動キャンセル（対戦中の二重応募防止）
    UPDATE battle_invite_applications
       SET status = 'cancelled', updated_at = now()
     WHERE applicant_id = p_user_id AND status = 'pending';

    RETURN json_build_object('success', true, 'room_id', v_room_id);
  ELSE
    UPDATE battle_invites
       SET status = 'declined', responded_at = now(), updated_at = now()
     WHERE id = p_invite_id;
    RETURN json_build_object('success', true);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO anon;
GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO authenticated;
GRANT ALL ON FUNCTION public.respond_resba(uuid, uuid, boolean) TO service_role;

-- ---------- 2. approve_post_resba: ホスト・応募者の対戦中チェック追加 ----------
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

-- ---------- 3. レスバ作成 RPC 群（上限なし・対戦中チェックのみ） ----------
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
  v_target       uuid;
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

  IF v_parent IS NOT NULL THEN
    SELECT user_id INTO v_target FROM bbs_comments WHERE id = v_parent;
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'PARENT_NOT_FOUND');
    END IF;
  ELSE
    SELECT user_id INTO v_target FROM bbs_posts WHERE id = v_post_id;
    IF NOT FOUND THEN
      RETURN json_build_object('success', false, 'error', 'POST_NOT_FOUND');
    END IF;
  END IF;

  IF v_target = p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'SELF_INVITE');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'comment', p_comment_id, v_target,
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

CREATE OR REPLACE FUNCTION public.create_post_resba(
  p_sender_id uuid,
  p_post_id   uuid,
  p_theme     text,
  p_choice1   text,
  p_choice2   text
)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_owner uuid;
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id INTO v_owner FROM bbs_posts WHERE id = p_post_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'POST_NOT_FOUND');
  END IF;
  IF v_owner <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_POST_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'post', p_post_id, NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_post_resba(uuid, uuid, text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.send_dm_resba(
  p_sender_id  uuid,
  p_message_id uuid,
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
  v_room   uuid;
  v_target uuid;
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT room_id INTO v_room FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;

  SELECT user_id INTO v_target
    FROM dm_room_members
   WHERE room_id = v_room AND user_id <> p_sender_id
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'TARGET_NOT_FOUND');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, target_user_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id, v_target,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.send_dm_resba(uuid, uuid, text, text, text) TO service_role;

-- ---------- 4. rooms_v2 の掃除修正 ----------
-- 従来: DELETE FROM rooms_v2 WHERE result IS NOT NULL ...  → result カラムが無いため常にエラー
-- 修正: rooms_v2 は winner 確定済み（かつ updated_at が自動更新される）ため winner ベースで削除
CREATE OR REPLACE FUNCTION public.delete_old_rooms_with_result()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  DELETE FROM public.rooms_v2
  WHERE
    winner IS NOT NULL
    AND updated_at <= now() - INTERVAL '2 minutes';
END;
$function$;

-- cron ジョブを確実に登録（jobname が既存なら更新される・冪等）
SELECT cron.schedule(
  'delete-old-rooms-v2',
  '*/5 * * * *',
  $$SELECT public.delete_old_rooms_with_result()$$
);

-- ---------- 5. 応募中の全取り消し（ランダムマッチ開始前など） ----------
CREATE OR REPLACE FUNCTION public.cancel_my_pending_applications(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  UPDATE battle_invite_applications
     SET status = 'cancelled', updated_at = now()
   WHERE applicant_id = p_user_id AND status = 'pending';
  RETURN json_build_object('success', true);
END;
$function$;

GRANT ALL ON FUNCTION public.cancel_my_pending_applications(uuid) TO anon;
GRANT ALL ON FUNCTION public.cancel_my_pending_applications(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.cancel_my_pending_applications(uuid) TO service_role;

-- ---------- 6. 自分がホストの pending レスバ一覧（保留応募の表示用） ----------
CREATE OR REPLACE FUNCTION public.get_my_pending_host_invites(p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT COALESCE(json_agg(json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'created_at', b.created_at,
      'is_sender', true,
      'first_application', (
        SELECT json_build_object(
          'id', a.id,
          'applicant_id', a.applicant_id,
          'applicant_name', au.name,
          'applicant_avatar', au.avatar_url,
          'applicant_trophy', au.trophy
        )
        FROM battle_invite_applications a
        LEFT JOIN users au ON au.id = a.applicant_id
        WHERE a.invite_id = b.id AND a.status = 'pending'
        ORDER BY a.created_at ASC LIMIT 1
      )
    )), '[]'::json) INTO v_result
  FROM battle_invites b
  WHERE b.sender_id = p_user_id AND b.status = 'pending';
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_pending_host_invites(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_pending_host_invites(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_pending_host_invites(uuid) TO service_role;
