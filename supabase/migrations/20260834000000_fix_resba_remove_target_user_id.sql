-- ============================================================
-- Migration: 20260834000000_fix_resba_remove_target_user_id
-- battle_invites の target_user_id カラム削除に伴う
-- レスバ作成・取得RPCの修正
-- ============================================================

-- ---------- 1. create_post_resba ----------
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

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'post', p_post_id,
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

-- ---------- 2. attach_resba_to_comment ----------
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

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'comment', p_comment_id,
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

-- ---------- 3. send_dm_resba ----------
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
  v_msg_user uuid;
  v_invite   json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT sender_id INTO v_msg_user FROM dm_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;
  IF v_msg_user <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_MESSAGE_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'dm', p_message_id,
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

-- ---------- 4. create_open_chat_resba ----------
CREATE OR REPLACE FUNCTION public.create_open_chat_resba(
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
  v_msg_user uuid;
  v_invite   json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  SELECT user_id INTO v_msg_user FROM open_chat_messages WHERE id = p_message_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'MESSAGE_NOT_FOUND');
  END IF;
  IF v_msg_user <> p_sender_id THEN
    RETURN json_build_object('success', false, 'error', 'NOT_MESSAGE_OWNER');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'open_chat', p_message_id,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_open_chat_resba(uuid, uuid, text, text, text) TO service_role;

-- ---------- 5. create_recruit_resba ----------
CREATE OR REPLACE FUNCTION public.create_recruit_resba(
  p_sender_id uuid,
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
  v_invite json;
BEGIN
  IF public.is_user_in_battle(p_sender_id) THEN
    RETURN json_build_object('success', false, 'error', 'IN_BATTLE');
  END IF;

  INSERT INTO battle_invites (sender_id, attach_type, attach_id, theme, choice1, choice2)
  VALUES (
    p_sender_id, 'recruit', NULL,
    COALESCE(NULLIF(p_theme, ''), 'レスバ対戦'),
    NULLIF(p_choice1, ''), NULLIF(p_choice2, '')
  )
  RETURNING to_jsonb(battle_invites.*)::text::json INTO v_invite;

  RETURN json_build_object('success', true, 'invite', v_invite);
END;
$function$;

GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO anon;
GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO authenticated;
GRANT ALL ON FUNCTION public.create_recruit_resba(uuid, text, text, text) TO service_role;

-- ---------- 6. get_my_sent_resbas ----------
CREATE OR REPLACE FUNCTION public.get_my_sent_resbas(p_user_id uuid)
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
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', true,
      'application_count', (
        SELECT count(*) FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.status = 'pending'
      ),
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
    ) ORDER BY b.created_at DESC), '[]'::json) INTO v_result
  FROM battle_invites b
  WHERE b.sender_id = p_user_id;
  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO anon;
GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_my_sent_resbas(uuid) TO service_role;

-- ---------- 7. get_resba_invite ----------
CREATE OR REPLACE FUNCTION public.get_resba_invite(p_invite_id uuid, p_user_id uuid)
  RETURNS json
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
      'id', b.id,
      'sender_id', b.sender_id,
      'sender_name', u.name,
      'sender_avatar', u.avatar_url,
      'sender_trophy', u.trophy,
      'attach_type', b.attach_type,
      'attach_id', b.attach_id,
      'theme', b.theme,
      'choice1', b.choice1,
      'choice2', b.choice2,
      'status', b.status,
      'responder_id', b.responder_id,
      'battle_room_id', b.battle_room_id,
      'created_at', b.created_at,
      'responded_at', b.responded_at,
      'is_sender', (b.sender_id = p_user_id),
      'my_application', (
        SELECT a.status FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.applicant_id = p_user_id
         ORDER BY a.created_at DESC LIMIT 1
      ),
      'first_application', (
        CASE WHEN b.sender_id = p_user_id THEN (
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
        ) ELSE NULL END
      ),
      'application_count', (
        SELECT count(*) FROM battle_invite_applications a
         WHERE a.invite_id = b.id AND a.status = 'pending'
      )
    ) INTO v_result
  FROM battle_invites b
  LEFT JOIN users u ON u.id = b.sender_id
  WHERE b.id = p_invite_id;

  RETURN v_result;
END;
$function$;

GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_resba_invite(uuid, uuid) TO service_role;
